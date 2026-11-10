import pandas as pd

SRC = "data/2019-Dec.csv"
OUT = "data/events_sample.csv"
FRAC = 0.05          # giữ khoảng 5% user
CHUNK = 1000000

total_rows = 0
kept_rows = 0
first = True

for chunk in pd.read_csv(SRC, chunksize=CHUNK):
    total_rows += len(chunk)
    # quyết định theo user_id (cố định) nên cùng một user luôn được giữ hoặc bỏ cùng nhau
    h = (chunk["user_id"] * 2654435761) % (2**32) / 2**32
    sample = chunk[h < FRAC]
    kept_rows += len(sample)
    sample.to_csv(OUT, mode="w" if first else "a", header=first, index=False)
    first = False
    print(f"Da doc {total_rows:,} dong | da giu {kept_rows:,} dong")

users = pd.read_csv(OUT, usecols=["user_id"])["user_id"].nunique()
print("\n===== KET QUA =====")
print(f"So dong file goc : {total_rows:,}")
print(f"So dong sau sample: {kept_rows:,}")
print(f"So user sau sample: {users:,}")