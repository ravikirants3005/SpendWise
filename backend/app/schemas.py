from pydantic import BaseModel
from datetime import date

class ExpenseCreate(BaseModel):
    amount: float
    category: str
    description: str | None = None
    date: date | None = None
