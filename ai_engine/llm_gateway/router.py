"""
LLM Gateway - 统一的模型调用层
按任务类型自动路由到最合适的模型
"""

import json
from enum import Enum
from typing import Optional

import httpx
from loguru import logger


class TaskType(Enum):
    CODE_GENERATION = "code_generation"    # 代码生成 → DeepSeek-Coder
    MARKET_ANALYSIS = "market_analysis"    # 市场分析 → Qwen-72B / DeepSeek-V3
    CHAT = "chat"                          # 对话交互 → Qwen-14B (低延迟)
    RISK_ASSESSMENT = "risk_assessment"    # 风险评估 → 本地微调模型
    DATA_EXTRACTION = "data_extraction"    # 结构化提取 → Qwen-7B
    REASONING = "reasoning"                # 复杂推理 → DeepSeek-V3


# 任务 → 模型映射
TASK_MODEL_MAP = {
    TaskType.CODE_GENERATION: "deepseek-coder",
    TaskType.MARKET_ANALYSIS: "qwen-max",
    TaskType.CHAT: "qwen-plus",
    TaskType.RISK_ASSESSMENT: "qwen-turbo",
    TaskType.DATA_EXTRACTION: "qwen-turbo",
    TaskType.REASONING: "deepseek-chat",
}


class LLMRouter:
    """LLM 统一调用路由器"""

    def __init__(
        self,
        deepseek_key: Optional[str] = None,
        qwen_key: Optional[str] = None,
        local_model: Optional[str] = None,
    ):
        self.providers = {}

        if deepseek_key:
            self.providers["deepseek-coder"] = DeepSeekProvider(
                api_key=deepseek_key,
                model="deepseek-coder",
                base_url="https://api.deepseek.com",
            )
            self.providers["deepseek-chat"] = DeepSeekProvider(
                api_key=deepseek_key,
                model="deepseek-chat",
                base_url="https://api.deepseek.com",
            )

        if qwen_key:
            for model in ["qwen-max", "qwen-plus", "qwen-turbo"]:
                self.providers[model] = QwenProvider(
                    api_key=qwen_key,
                    model=model,
                )

        logger.info(f"LLM Router initialized with providers: {list(self.providers.keys())}")

    async def call(
        self,
        prompt: str,
        task_type: TaskType = TaskType.CHAT,
        system_prompt: Optional[str] = None,
        model: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
        response_format: Optional[str] = None,
    ) -> str:
        """
        调用 LLM
        
        Args:
            prompt: 用户提示词
            task_type: 任务类型（自动选择模型）
            system_prompt: 系统提示词
            model: 指定模型（覆盖自动选择）
            temperature: 温度参数
            max_tokens: 最大 token 数
            response_format: 响应格式 ("json" 等)
        """
        # 选择模型
        model_name = model or TASK_MODEL_MAP.get(task_type, "qwen-plus")
        provider = self.providers.get(model_name)

        if not provider:
            # 回退到可用模型
            if self.providers:
                model_name = list(self.providers.keys())[0]
                provider = self.providers[model_name]
                logger.warning(f"Model {model_name} not found, falling back to {model_name}")
            else:
                raise RuntimeError("No LLM provider configured")

        logger.info(f"LLM call: model={model_name}, task={task_type.value}, tokens={max_tokens}")

        try:
            result = await provider.call(
                prompt=prompt,
                system_prompt=system_prompt,
                temperature=temperature,
                max_tokens=max_tokens,
                response_format=response_format,
            )
            return result
        except Exception as e:
            logger.error(f"LLM call failed: {e}")
            raise

    async def call_json(
        self,
        prompt: str,
        task_type: TaskType = TaskType.DATA_EXTRACTION,
        system_prompt: Optional[str] = None,
    ) -> dict:
        """调用 LLM 并解析 JSON 响应"""
        result = await self.call(
            prompt=prompt,
            task_type=task_type,
            system_prompt=system_prompt,
            response_format="json",
        )
        try:
            # 尝试从响应中提取 JSON
            if "```json" in result:
                json_str = result.split("```json")[1].split("```")[0].strip()
            elif "```" in result:
                json_str = result.split("```")[1].split("```")[0].strip()
            else:
                json_str = result
            return json.loads(json_str)
        except json.JSONDecodeError:
            logger.warning(f"Failed to parse JSON from LLM response: {result[:200]}")
            return {"raw_response": result}


class DeepSeekProvider:
    """DeepSeek API 提供者"""

    def __init__(self, api_key: str, model: str, base_url: str):
        self.api_key = api_key
        self.model = model
        self.base_url = base_url
        self.client = httpx.AsyncClient(timeout=60.0)

    async def call(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
        response_format: Optional[str] = None,
    ) -> str:
        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        messages.append({"role": "user", "content": prompt})

        body = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens,
        }

        if response_format == "json":
            body["response_format"] = {"type": "json_object"}

        resp = await self.client.post(
            f"{self.base_url}/v1/chat/completions",
            json=body,
            headers={"Authorization": f"Bearer {self.api_key}"},
        )
        resp.raise_for_status()
        data = resp.json()
        return data["choices"][0]["message"]["content"]


class QwenProvider:
    """通义千问 API 提供者 (兼容 OpenAI 格式)"""

    def __init__(self, api_key: str, model: str):
        self.api_key = api_key
        self.model = model
        self.client = httpx.AsyncClient(timeout=60.0)
        self.base_url = "https://dashscope.aliyuncs.com/compatible-mode/v1"

    async def call(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 4096,
        response_format: Optional[str] = None,
    ) -> str:
        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        messages.append({"role": "user", "content": prompt})

        body = {
            "model": self.model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens,
        }

        if response_format == "json":
            body["response_format"] = {"type": "json_object"}

        resp = await self.client.post(
            f"{self.base_url}/chat/completions",
            json=body,
            headers={"Authorization": f"Bearer {self.api_key}"},
        )
        resp.raise_for_status()
        data = resp.json()
        return data["choices"][0]["message"]["content"]
