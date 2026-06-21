from pydantic import BaseModel, Field, field_validator


class NutritionTargets(BaseModel):
    calories: int = Field(ge=1200, le=6000)
    protein_grams: int = Field(ge=40, le=400)
    carb_grams: int = Field(ge=50, le=800)
    fat_grams: int = Field(ge=30, le=250)
    water_ml: int = Field(ge=1000, le=7000)


class Profile(BaseModel):
    age: int = Field(ge=18, le=100)
    height_cm: float = Field(ge=120, le=230)
    weight_kg: float = Field(ge=35, le=300)
    sex: str
    activity_level: str
    goal: str
    training_days_per_week: int = Field(ge=0, le=7)


class WeeklyPlanRequest(BaseModel):
    profile: Profile
    targets: NutritionTargets
    allergies: list[str] = Field(default_factory=list, max_length=20)
    disliked_foods: list[str] = Field(default_factory=list, max_length=30)


class PlannedMeal(BaseModel):
    title: str = Field(min_length=1, max_length=80)
    description: str = Field(min_length=3, max_length=300)
    calories: int = Field(ge=50, le=2500)
    protein_grams: int = Field(ge=0, le=200)
    shopping_items: list[str] = Field(min_length=1, max_length=20)


class DailyPlan(BaseModel):
    day_label: str
    training_day: bool
    meals: list[PlannedMeal] = Field(min_length=3, max_length=6)

    @field_validator("meals")
    @classmethod
    def validate_daily_calories(cls, meals: list[PlannedMeal]) -> list[PlannedMeal]:
        if sum(meal.calories for meal in meals) <= 0:
            raise ValueError("Günlük kalori toplamı sıfır olamaz.")
        return meals


class WeeklyPlanResponse(BaseModel):
    targets: NutritionTargets
    days: list[DailyPlan] = Field(min_length=7, max_length=7)
    source: str = "groq"
