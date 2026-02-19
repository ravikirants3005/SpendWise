from fastapi import FastAPI
from app.schemas import ExpenseCreate
from app.crud import (
    add_expense,
    get_all_expenses,
    get_today_total,
    get_month_total,
    delete_expense
)

app = FastAPI()

FAKE_USER_ID = "00000000-0000-0000-0000-000000000000"


@app.get("/")
def root():
    return {"message": "SpendWise API is running 🚀"}


@app.post("/expenses/add")
async def create_expense(expense: ExpenseCreate):
    return await add_expense(FAKE_USER_ID, expense)


@app.get("/expenses/all")
async def read_expenses():
    return await get_all_expenses(FAKE_USER_ID)


@app.get("/expenses/today")
async def today_total():
    total = await get_today_total(FAKE_USER_ID)
    return {"today_total": total}


@app.get("/expenses/month")
async def month_total():
    total = await get_month_total(FAKE_USER_ID)
    return {"month_total": total}


@app.delete("/expenses/{expense_id}")
async def remove_expense(expense_id: str):
    deleted = await delete_expense(FAKE_USER_ID, expense_id)
    return {"message": "Expense deleted"}
