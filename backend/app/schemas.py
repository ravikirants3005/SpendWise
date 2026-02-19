from datetime import date as DateType

from pydantic import BaseModel

class ExpenseCreate(BaseModel):
    amount: float
    category: str
    description: str | None = None
    date: DateType | None = None
