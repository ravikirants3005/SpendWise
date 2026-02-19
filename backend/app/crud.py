from datetime import date
from app.db import supabase

TABLE = "expenses"

# ➜ ADD EXPENSE
async def add_expense(user_id, expense):
    data = {
        "user_id": user_id,
        "amount": expense.amount,
        "category": expense.category,
        "description": expense.description,
        "date": str(date.today())
    }

    res = supabase.table(TABLE).insert(data).execute()
    return {"message": "Expense added successfully"}

# ➜ GET ALL EXPENSES
async def get_all_expenses(user_id):
    res = supabase.table(TABLE)\
        .select("*")\
        .eq("user_id", user_id)\
        .order("date", desc=True)\
        .execute()

    return res.data

# ➜ TODAY TOTAL ⭐⭐⭐ FIXED
async def get_today_total(user_id):
    today = str(date.today())

    res = supabase.table(TABLE)\
        .select("amount")\
        .eq("user_id", user_id)\
        .eq("date", today)\
        .execute()

    total = sum(item["amount"] for item in res.data)
    return total

# ➜ MONTH TOTAL ⭐⭐⭐ FIXED
async def get_month_total(user_id):
    month_prefix = str(date.today())[:7]  # "2026-02"

    res = supabase.table(TABLE)\
        .select("amount,date")\
        .eq("user_id", user_id)\
        .execute()

    monthly = [
        item["amount"]
        for item in res.data
        if item["date"].startswith(month_prefix)
    ]

    return sum(monthly)

# ➜ DELETE EXPENSE
async def delete_expense(user_id, expense_id):
    res = supabase.table(TABLE)\
        .delete()\
        .eq("id", expense_id)\
        .eq("user_id", user_id)\
        .execute()

    return True