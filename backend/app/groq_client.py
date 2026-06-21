import json
import logging
import os
import re

import httpx

from .schemas import WeeklyPlanRequest, WeeklyPlanResponse

GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
logger = logging.getLogger(__name__)


class GroqClient:
    def __init__(self) -> None:
        self.api_key = os.getenv("GROQ_API_KEY", "").strip()
        self.model = os.getenv("GROQ_MODEL", "qwen/qwen3-32b").strip()

    async def create_weekly_plan(
        self, request: WeeklyPlanRequest
    ) -> WeeklyPlanResponse:
        if not self.api_key:
            raise RuntimeError("GROQ_API_KEY tanımlı değil.")

        prompt = self._build_prompt(request)
        async with httpx.AsyncClient(timeout=70) as client:
            response = await client.post(
                GROQ_URL,
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": self.model,
                    "temperature": 0.35,
                    # Ücretsiz Qwen kotasında istek + olası çıktı toplamı
                    # dakika başına token sınırını aşmamalı.
                    "max_completion_tokens": 4000,
                    "reasoning_format": "hidden",
                    "response_format": {"type": "json_object"},
                    "messages": [
                        {
                            "role": "system",
                            "content": (
                                "Sen güvenli ve pratik bir Türkçe beslenme planı "
                                "yardımcısısın. Tıbbi tanı veya tedavi önermezsin. "
                                "Yalnızca istenen JSON'u üretirsin."
                            ),
                        },
                        {"role": "user", "content": prompt},
                    ],
                },
            )
        if response.status_code == 429:
            raise RuntimeError("Groq ücretsiz kotası veya hız sınırı aşıldı.")
        if response.status_code >= 400:
            detail = response.text[:300]
            raise RuntimeError(f"Groq hatası ({response.status_code}): {detail}")

        payload = response.json()
        content = payload["choices"][0]["message"]["content"]
        parsed = self._parse_json(content)
        parsed["targets"] = request.targets.model_dump()
        parsed["source"] = f"groq:{self.model}"
        plan = WeeklyPlanResponse.model_validate(parsed)
        return self._normalize_plan(plan, request)

    def _build_prompt(self, request: WeeklyPlanRequest) -> str:
        data = request.model_dump()
        return f"""
Aşağıdaki profil ve uygulama tarafından hesaplanmış hedeflere göre 7 günlük,
Türk mutfağına uygun, ulaşılabilir malzemeler içeren bir plan oluştur.

Kurallar:
- Kalori ve makro hedeflerini yeniden hesaplama; verilen hedeflere uy.
- Her gün 4 öğün olsun: Kahvaltı, Öğle, Ara öğün, Akşam.
- Açıklamaları kısa tut; her öğünde en fazla 5 alışveriş kalemi yaz.
- Her günün toplam kalorisi hedefin yüzde 10 yakınında olsun.
- Her günün toplam proteini protein hedefinin en az yüzde 85'i olsun.
- Antrenman günü sayısı profile uygun olsun.
- Alerjenleri ve sevilmeyen yemekleri kesinlikle kullanma.
- Takviye, ilaç, aşırı kalori açığı veya tıbbi öneri verme.
- Yemekleri Türkçe yaz.

Girdi:
{json.dumps(data, ensure_ascii=False)}

Yanıt SADECE şu yapıda geçerli JSON olsun:
{{
  "days": [
    {{
      "day_label": "Pazartesi",
      "training_day": true,
      "meals": [
        {{
          "title": "Kahvaltı",
          "description": "Miktarlarıyla kısa yemek açıklaması",
          "calories": 500,
          "protein_grams": 30,
          "shopping_items": ["Yulaf", "Yoğurt"]
        }}
      ]
    }}
  ]
}}
"""

    def _parse_json(self, content: str) -> dict:
        clean = content.strip()
        clean = re.sub(r"^```(?:json)?", "", clean)
        clean = re.sub(r"```$", "", clean).strip()
        return json.loads(clean)

    def _normalize_plan(
        self, plan: WeeklyPlanResponse, request: WeeklyPlanRequest
    ) -> WeeklyPlanResponse:
        # Modelin küçük sayısal sapmaları tüm planı bozmasın. Uygulamanın
        # deterministik hedefleri son otoritedir.
        preferred_training_days = [0, 2, 4, 5, 1, 3, 6]
        training_indexes = set(
            preferred_training_days[: request.profile.training_days_per_week]
        )
        target = request.targets.calories
        protein_target = request.targets.protein_grams

        for index, day in enumerate(plan.days):
            day.training_day = index in training_indexes

            total = sum(meal.calories for meal in day.meals)
            if total <= 0:
                raise ValueError(f"{day.day_label} için geçerli kalori üretilemedi.")
            calorie_scale = target / total
            for meal in day.meals:
                meal.calories = max(50, round(meal.calories * calorie_scale))

            # Yuvarlamadan kalan farkı son öğüne ekle.
            calorie_difference = target - sum(meal.calories for meal in day.meals)
            day.meals[-1].calories = max(
                50, day.meals[-1].calories + calorie_difference
            )

            total_protein = sum(meal.protein_grams for meal in day.meals)
            if total_protein > 0 and total_protein < protein_target * 0.85:
                protein_scale = protein_target / total_protein
                for meal in day.meals:
                    meal.protein_grams = max(
                        0, round(meal.protein_grams * protein_scale)
                    )

        logger.info(
            "AI planı normalize edildi: calories=%s training_days=%s",
            target,
            request.profile.training_days_per_week,
        )
        return plan
