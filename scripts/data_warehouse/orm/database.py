import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Database connection setup for postgreSQL
# Database name: emilioig_db
# username: emilioig
# password: Emitgo_03
DATABASE_URL = os.getenv("DATABASE_URL") or "postgresql://emilioig:Emitgo_03@localhost:15432/emilioig_db"

engine = create_engine(DATABASE_URL, echo=False, future=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)

def get_session():
    return SessionLocal()
