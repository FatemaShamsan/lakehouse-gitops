"""Demo Bronze -> Silver job: load raw orders, quarantine bad rows, MERGE valid rows into Silver."""
from pyspark.sql import SparkSession, functions as F

spark = SparkSession.builder.appName("bronze-to-silver").getOrCreate()
spark.sql("CREATE NAMESPACE IF NOT EXISTS lh.bronze")
spark.sql("CREATE NAMESPACE IF NOT EXISTS lh.silver")

# Bronze: raw data exactly as landed (sample data, deliberately includes bad rows and a duplicate)
raw = spark.createDataFrame(
    [(1, "alice", "10.5", "2026-11-01"), (2, "bob", "20.0", "2026-11-01"),
     (2, "bob", "20.0", "2026-11-01"), (3, None, "7.0", "2026-11-02"),
     (4, "dina", "abc", "2026-11-02")],
    "order_id INT, customer STRING, amount STRING, order_date STRING")
raw.writeTo("lh.bronze.orders_raw").createOrReplace()

df = spark.table("lh.bronze.orders_raw").withColumn("amount_num", F.col("amount").cast("double"))
ok = (F.col("customer").isNotNull()) & (F.col("amount_num").isNotNull())

# Quarantine: rejected rows with a reason
(df.filter(~ok).withColumn("reason",
    F.when(F.col("customer").isNull(), "customer is null").otherwise("amount is not a number"))
   .writeTo("lh.silver.orders_quarantine").createOrReplace())

# Silver: typed, deduplicated, upserted
good = (df.filter(ok).dropDuplicates(["order_id"])
          .select("order_id", "customer", F.col("amount_num").alias("amount"),
                  F.to_date("order_date").alias("order_date")))
good.createOrReplaceTempView("updates")
spark.sql("""CREATE TABLE IF NOT EXISTS lh.silver.orders
             (order_id INT, customer STRING, amount DOUBLE, order_date DATE) USING iceberg""")
spark.sql("""MERGE INTO lh.silver.orders t USING updates u ON t.order_id = u.order_id
             WHEN MATCHED THEN UPDATE SET * WHEN NOT MATCHED THEN INSERT *""")
print("silver rows:", spark.table("lh.silver.orders").count())
