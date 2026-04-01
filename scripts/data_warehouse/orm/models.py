import os
from sqlalchemy import (
    Column,
    BigInteger,
    Integer,
    String,
    Boolean,
    Date,
    DateTime,
    Numeric,
    ForeignKey,
    UniqueConstraint,
    Index,
)
from sqlalchemy.orm import relationship, declarative_base
from sqlalchemy.types import Enum as SAEnum

Base = declarative_base()

# schema name for objects; set via env var DW_SCHEMA (e.g. 'dw')
SCHEMA = os.getenv("DW_SCHEMA", "dw")


class DimDate(Base):
    __tablename__ = "dim_date"
    __table_args__ = {"schema": SCHEMA}

    sk_date_id = Column(BigInteger, primary_key=True)
    datetime = Column(DateTime, nullable=False, unique=True)
    date = Column(Date)
    hour = Column(Integer)
    minute = Column(Integer)
    second = Column(Integer)
    day_of_week = Column(Integer)
    day_name = Column(String(20))
    day_of_month = Column(Integer)
    day_of_year = Column(Integer)
    week_of_month = Column(Integer)
    week_of_year = Column(Integer)
    month = Column(Integer)
    month_name = Column(String(20))
    year = Column(Integer)
    quarter = Column(Integer)
    is_weekend = Column(Boolean)
    is_holiday = Column(Boolean)
    fiscal_year = Column(Integer)
    fiscal_quarter = Column(Integer)


class DimExchange(Base):
    __tablename__ = "dim_exchange"
    __table_args__ = {"schema": SCHEMA}

    sk_exchange_id = Column(BigInteger, primary_key=True, autoincrement=True)
    exchange_code = Column(String(10), nullable=False, unique=True)
    exchange_name = Column(String(100))


class DimCompany(Base):
    __tablename__ = "dim_company"
    __table_args__ = ({"schema": SCHEMA})

    sk_company_id = Column(BigInteger, primary_key=True, autoincrement=True)
    symbol = Column(String(10), index=True, unique=True)
    company_name = Column(String(255))
    ceo = Column(String(255))
    currency = Column(String(10))
    sector = Column(String(100))
    industry = Column(String(100))
    full_time_employees = Column(Integer)
    country = Column(String(100))
    state = Column(String(100))
    city = Column(String(100))
    zip = Column(String(20))
    address = Column(String(255))
    ipo_date = Column(Date)
    is_active = Column(Boolean, default=True)
    is_etf = Column(Boolean, default=False)
    is_fund = Column(Boolean, default=False)
    row_effective_ts = Column(DateTime)
    row_end_ts = Column(DateTime)


class DimMetaAuditLog(Base):
    __tablename__ = "dim_meta_audit_log"
    __table_args__ = {"schema": SCHEMA}

    sk_audit_id = Column(BigInteger, primary_key=True, autoincrement=True)
    source_system = Column(String(100))
    row_count_raw = Column(BigInteger)
    row_count_rejected = Column(BigInteger)
    execution_start_ts = Column(DateTime)
    execution_end_ts = Column(DateTime)
    execution_time = Column(Numeric(6, 2))
    status = Column(String(50))


class DimInstrument(Base):
    __tablename__ = "dim_instrument"
    __table_args__ = (
        UniqueConstraint("instrument_type", "symbol", name="uq_instrument_natural_key"),
        {"schema": SCHEMA},
    )

    sk_instrument_id = Column(BigInteger, primary_key=True, autoincrement=True)
    instrument_type = Column(String(50), nullable=False)
    symbol = Column(String(50), nullable=False, unique=True)
    name = Column(String(255))
    currency = Column(String(10))

class FactStockPrice(Base):
    __tablename__ = "fact_15min_stock_price"
    __table_args__ = (
        UniqueConstraint("fk_date_id", "fk_instrument_id", name="uq_fact_grain"),
        UniqueConstraint("sk_fact_id", "fk_date_id", name="pk_fact_15min_stock"), 
        Index("ix_fact_date_instrument", "fk_date_id", "fk_instrument_id"),
        {"schema": SCHEMA,
         "postgresql_partition_by": "RANGE (fk_date_id)"},
    )

    sk_fact_id = Column(BigInteger, primary_key=True, autoincrement=True)
    fk_date_id = Column(BigInteger, ForeignKey(f"{SCHEMA}.dim_date.sk_date_id"), nullable=False, primary_key=True)
    fk_instrument_id = Column(BigInteger, ForeignKey(f"{SCHEMA}.dim_instrument.sk_instrument_id"), nullable=False)
    fk_exchange_id = Column(BigInteger, ForeignKey(f"{SCHEMA}.dim_exchange.sk_exchange_id"), nullable=True)
    fk_audit_id = Column(BigInteger, ForeignKey(f"{SCHEMA}.dim_meta_audit_log.sk_audit_id"), nullable=True)
    fk_company_id = Column(BigInteger, ForeignKey(f"{SCHEMA}.dim_company.sk_company_id"), nullable=True)

    trade_count = Column(Integer)
    open_price = Column(Numeric(18, 6))
    high_price = Column(Numeric(18, 6))
    low_price = Column(Numeric(18, 6))
    close_price = Column(Numeric(18, 6))
    volume = Column(BigInteger)
    adj_close = Column(Numeric(18, 6))
    vwap = Column(Numeric(18, 6))
    previous_close = Column(Numeric(18, 6))
    price_change = Column(Numeric(18, 6))
    price_change_pct = Column(Numeric(7, 3))
    price_range = Column(Numeric(18, 6))

    date = relationship("DimDate")
    instrument = relationship("DimInstrument")
    exchange = relationship("DimExchange")
    audit = relationship("DimMetaAuditLog")
    company = relationship("DimCompany")
