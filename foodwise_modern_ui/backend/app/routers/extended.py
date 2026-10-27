from datetime import date, timedelta
from io import BytesIO
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from sqlalchemy import select, func
from app.deps import Db, CurrentUser
from app.models import NutritionGoal, UserProfile, WaterLog, FavoriteFood, Food, MealLog

router = APIRouter(tags=["tracking"])

class GoalIn(BaseModel):
    calories: int = Field(ge=1, le=20000)
    protein: int = Field(ge=0, le=2000)
    carbs: int = Field(ge=0, le=3000)
    fat: int = Field(ge=0, le=2000)
    water_ml: int = Field(ge=100, le=15000)

class ProfileIn(BaseModel):
    age: int | None = Field(default=None, ge=1, le=120)
    height_cm: float | None = Field(default=None, gt=0, le=300)
    weight_kg: float | None = Field(default=None, gt=0, le=500)

class WaterIn(BaseModel):
    consumed_on: date
    amount_ml: int = Field(gt=0, le=5000)

def get_or_create(db, cls, user_id):
    obj = db.get(cls, user_id)
    if obj is None:
        obj = cls(user_id=user_id)
        db.add(obj)
        db.commit()
        db.refresh(obj)
    return obj

def fields(obj, keys):
    return {k: getattr(obj, k) for k in keys}

@router.get('/goals')
def read_goals(db: Db, user: CurrentUser):
    return fields(get_or_create(db, NutritionGoal, user.id), ('calories','protein','carbs','fat','water_ml'))

@router.put('/goals')
def update_goals(data: GoalIn, db: Db, user: CurrentUser):
    obj = get_or_create(db, NutritionGoal, user.id)
    for key, val in data.model_dump().items(): setattr(obj, key, val)
    db.commit()
    return fields(obj, ('calories','protein','carbs','fat','water_ml'))

@router.get('/profile')
def read_profile(db: Db, user: CurrentUser):
    out = fields(get_or_create(db, UserProfile, user.id), ('age','height_cm','weight_kg'))
    return dict(out, name=user.name, email=user.email)

@router.put('/profile')
def update_profile(data: ProfileIn, db: Db, user: CurrentUser):
    obj = get_or_create(db, UserProfile, user.id)
    for key, val in data.model_dump().items(): setattr(obj, key, val)
    db.commit()
    return read_profile(db, user)

@router.get('/water')
def read_water(on: date, db: Db, user: CurrentUser):
    logs = db.scalars(select(WaterLog).where(WaterLog.user_id == user.id, WaterLog.consumed_on == on).order_by(WaterLog.id.desc())).all()
    return {'date': on, 'total_ml': sum(x.amount_ml for x in logs), 'logs': [{'id': x.id, 'amount_ml': x.amount_ml} for x in logs]}

@router.post('/water', status_code=201)
def add_water(data: WaterIn, db: Db, user: CurrentUser):
    obj = WaterLog(user_id=user.id, **data.model_dump())
    db.add(obj); db.commit(); db.refresh(obj)
    return {'id':obj.id, 'amount_ml':obj.amount_ml}

@router.delete('/water/{water_id}', status_code=204)
def delete_water(water_id: int, db: Db, user: CurrentUser):
    obj = db.scalar(select(WaterLog).where(WaterLog.id==water_id, WaterLog.user_id==user.id))
    if obj is None: raise HTTPException(404, 'Water log not found')
    db.delete(obj); db.commit()

@router.get('/favorites')
def favorites(db: Db, user: CurrentUser):
    return [x.food_id for x in db.scalars(select(FavoriteFood).where(FavoriteFood.user_id==user.id)).all()]

@router.post('/favorites/{food_id}', status_code=201)
def add_favorite(food_id: int, db: Db, user: CurrentUser):
    if not db.get(Food, food_id): raise HTTPException(404, 'Food not found')
    if not db.get(FavoriteFood, (user.id, food_id)):
        db.add(FavoriteFood(user_id=user.id, food_id=food_id)); db.commit()
    return {'food_id':food_id}

@router.delete('/favorites/{food_id}', status_code=204)
def remove_favorite(food_id: int, db: Db, user: CurrentUser):
    obj = db.get(FavoriteFood, (user.id,food_id))
    if obj: db.delete(obj); db.commit()

def report_rows(start_date, end_date, db, uid):
    if end_date < start_date or (end_date-start_date).days > 365:
        raise HTTPException(400, 'Date range must be 0-365 days')
    logs=db.scalars(select(MealLog).where(MealLog.user_id==uid, MealLog.eaten_on>=start_date, MealLog.eaten_on<=end_date)).all()
    results={}
    for i in range((end_date-start_date).days+1):
        day=(start_date+timedelta(days=i)).isoformat()
        results[day]={'date':day,'calories':0.0,'protein':0.0,'carbs':0.0,'fat':0.0}
    foods={f.id:f for f in db.scalars(select(Food).where(Food.id.in_([m.food_id for m in logs]))).all()} if logs else {}
    for log in logs:
        row=results[log.eaten_on.isoformat()]
        food=foods.get(log.food_id)
        if food:
            for key in ('calories','protein','carbs','fat'):
                row[key]+=float(getattr(food,key))*float(log.quantity_grams)/100
    return [dict(r, **{k:round(r[k],2) for k in ('calories','protein','carbs','fat')}) for r in results.values()]

@router.get('/reports/summary')
def range_summary(start_date: date, end_date: date, db: Db, user: CurrentUser):
    rows=report_rows(start_date,end_date,db,user.id)
    keys=('calories','protein','carbs','fat')
    return {'days':rows,'totals':{k:round(sum(r[k] for r in rows),2) for k in keys},'averages':{k:round(sum(r[k] for r in rows)/len(rows),2) for k in keys}}

@router.get('/reports/pdf')
def pdf_report(start_date: date, end_date: date, db: Db, user: CurrentUser):
    from reportlab.pdfgen import canvas
    rows=report_rows(start_date,end_date,db,user.id)
    buffer=BytesIO(); pdf=canvas.Canvas(buffer, pagesize=(595,842)); y=790
    pdf.setFont('Helvetica-Bold',18); pdf.drawString(35,y,'FoodWise Nutrition Report'); y-=30
    pdf.setFont('Helvetica',11); pdf.drawString(35,y,f'{start_date} to {end_date}'); y-=35
    for r in rows:
        pdf.drawString(35,y,f"{r['date']}: {r['calories']} kcal | P {r['protein']}g | C {r['carbs']}g | F {r['fat']}g")
        y-=19
        if y < 45: pdf.showPage(); y=790; pdf.setFont('Helvetica',11)
    pdf.save(); buffer.seek(0)
    return StreamingResponse(buffer, media_type='application/pdf', headers={'Content-Disposition':'attachment; filename=foodwise-report.pdf'})
