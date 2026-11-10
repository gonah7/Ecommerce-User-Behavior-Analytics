# %% Thiet lap
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import statsmodels.formula.api as smf
from scipy import stats

ROOT = Path.cwd()
if ROOT.name == "notebooks":
    ROOT = ROOT.parent
DATA = ROOT / "data"
FIG = ROOT / "report" / "figures"
FIG.mkdir(parents=True, exist_ok=True)
sns.set_theme(style="whitegrid")


# %% Doc du lieu va kiem tra so bo
def load(name, cols, **kw):
    path = DATA / name
    with open(path, encoding="utf-8-sig") as f:
        first = f.readline()
    sep = ";" if first.count(";") > first.count(",") else ","
    has_header = cols[0] in first
    return pd.read_csv(path, sep=sep, encoding="utf-8-sig", header=0 if has_header else None, names=None if has_header else cols, **kw)


daily = load("daily_kpi.csv", ["full_date", "weekday_name", "dau", "events", "buyers", "revenue"],
             parse_dates=["full_date"])
cohort = load("cohort.csv", ["cohort_wk", "cohort_start", "weeks_since", "active_users", "cohort_size", "retention_pct"],
              parse_dates=["cohort_start"])
rfm = load("user_rfm.csv", ["user_id", "recency_days", "frequency", "items_bought", "monetary", "r_score", "m_score", "segment"])
ud = load("user_day.csv", ["user_id", "full_date", "user_type", "bought", "revenue"],
          parse_dates=["full_date"])

print("Du lieu theo ngay:", daily.shape, "| Tong doanh thu:", round(daily.revenue.sum(), 2))
print("Du lieu Cohort:", cohort.shape)
print("Du lieu RFM:", rfm.shape, "| Tong gia tri mua hang:", round(rfm.monetary.sum(), 2))
print("Du lieu nguoi dung theo ngay:", ud.shape, "| Tong doanh thu:", round(ud.revenue.sum(), 2))


# %% Bieu do 1: Xu huong DAU va doanh thu hang ngay
plt.figure(figsize=(11, 7))

plt.subplot(2, 1, 1)
plt.plot(daily.full_date, daily.dau, marker="o")
plt.axvline(pd.Timestamp("2019-12-15"), color="red", linestyle="--", alpha=0.6)
plt.title("So nguoi dung hoat dong va doanh thu hang ngay - Thang 12/2019")
plt.ylabel("So nguoi dung hoat dong (DAU)")
plt.text(pd.Timestamp("2019-12-15"), daily.dau.max(), "  Bien dong ro ret quanh ngay 15-16/12", color="red", va="top")

plt.subplot(2, 1, 2)
plt.plot(daily.full_date, daily.revenue / 1e3, marker="o", color="tab:green")
plt.axvline(pd.Timestamp("2019-12-15"), color="red", linestyle="--", alpha=0.6)
plt.title("Xu huong doanh thu hang ngay")
plt.ylabel("Doanh thu (nghin)")
plt.xticks(rotation=45)

plt.tight_layout()
plt.savefig(FIG / "01_daily_trend.png", dpi=150)


# %% Bieu do 2: Ban do nhiet ty le giu chan khach hang theo Cohort
size = cohort[cohort.weeks_since == 0].set_index("cohort_start")["cohort_size"]
p = cohort[cohort.weeks_since > 0].pivot(index="cohort_start", columns="weeks_since", values="retention_pct")
p.index = [f"{d:%d/%m} (n={size[d]:,})" for d in p.index]
p.columns = [f"Tuan +{c}" for c in p.columns]

plt.figure(figsize=(8, 4))
sns.heatmap(p, annot=True, fmt=".1f", cmap="Blues", vmin=0, vmax=40, cbar_kws={"label": "Ty le giu chan (%)"})
plt.title("Ty le giu chan nguoi dung theo Cohort hang tuan")
plt.ylabel("Cohort (tuan hoat dong dau tien)")
plt.xlabel("So tuan ke tu khi bat dau")
plt.tight_layout()
plt.savefig(FIG / "02_cohort_heatmap.png", dpi=150)


# %% Bieu do 3: Phan khuc RFM - Ty trong nguoi mua va doanh thu
order = ["Champions", "Loyal", "At risk", "Recent buyers", "Need attention", "Hibernating"]
seg = rfm.groupby("segment").agg(users=("user_id", "count"), revenue=("monetary", "sum"))
seg["% of buyers"] = 100 * seg.users / seg.users.sum()
seg["% of revenue"] = 100 * seg.revenue / seg.revenue.sum()
seg = seg.loc[order]

# Viet hoa ten cac phan khuc va cot ket qua
ten_phan_khuc = {
    "Champions": "Khach hang hang dau",
    "Loyal": "Khach hang trung thanh",
    "At risk": "Khach hang co nguy co roi bo",
    "Recent buyers": "Khach hang moi mua",
    "Need attention": "Khach hang can quan tam",
    "Hibernating": "Khach hang khong hoat dong"
}

seg = seg.rename(index=ten_phan_khuc)
seg = seg.rename(columns={
    "users": "So luong nguoi mua",
    "revenue": "Doanh thu",
    "% of buyers": "Ty trong nguoi mua (%)",
    "% of revenue": "Ty trong doanh thu (%)"
})

print("\nKet qua phan tich theo phan khuc RFM:")
print(seg.round(2))

seg[["Ty trong nguoi mua (%)", "Ty trong doanh thu (%)"]].plot(kind="bar", figsize=(10, 5))
plt.title("Phan khuc RFM: Ty trong nguoi mua va doanh thu")
plt.ylabel("Ty trong (%)")
plt.xlabel("Phan khuc khach hang")
plt.xticks(rotation=20)
plt.grid(axis="x", visible=False)
plt.legend(["Ty trong nguoi mua", "Ty trong doanh thu"])
plt.tight_layout()
plt.savefig(FIG / "03_rfm_segments.png", dpi=150)


# Kiem tra muc do tap trung doanh thu
s = rfm.monetary.sort_values(ascending=False).reset_index(drop=True)
n = len(s)
print("\nTy trong doanh thu tu nhom 1% nguoi mua hang dau:",
      round(100 * s.iloc[: int(np.ceil(0.01 * n))].sum() / s.sum(), 2), "%")
print("Ty trong doanh thu tu nhom 10% nguoi mua hang dau:",
      round(100 * s.iloc[: int(np.ceil(0.10 * n))].sum() / s.sum(), 2), "%")


# %% Kiem dinh thong ke: So sanh ty le mua hang truoc va sau ngay 16/12
ud["period"] = np.select(
    [
        ud.full_date.between("2019-12-08", "2019-12-14"),
        ud.full_date >= "2019-12-16"
    ],
    ["Truoc", "Sau"],
    default="Bo qua"
)

w = ud[ud.period != "Bo qua"].copy()
w["after"] = (w.period == "Sau").astype(int)

print("\nTy le mua hang theo giai doan va nhom nguoi dung:")
print(
    w.groupby(["period", "user_type"])
    .agg(
        so_luot_nguoi_dung=("bought", "size"),
        ty_le_mua_hang_pct=("bought", lambda x: 100 * x.mean())
    )
    .round(2)
)


# Kiem dinh A: Khoang tin cay, lay mau lai theo nguoi dung
def user_table(df):
    d = pd.DataFrame({
        "user_id": df.user_id.values,
        "n0": (df.after == 0).astype(int).values,
        "n1": df.after.values
    })
    d["b0"] = df.bought.values * d.n0
    d["b1"] = df.bought.values * d.n1
    return d.groupby("user_id")[["b0", "n0", "b1", "n1"]].sum().to_numpy()


def boot_diff(arr, B=2000, seed=42):
    rng = np.random.default_rng(seed)
    n = len(arr)
    point = 100 * (arr[:, 2].sum() / arr[:, 3].sum() - arr[:, 0].sum() / arr[:, 1].sum())
    diffs = np.empty(B)

    for i in range(B):
        t = arr[rng.integers(0, n, n)].sum(axis=0)
        diffs[i] = 100 * (t[2] / t[3] - t[0] / t[1])

    lo, hi = np.percentile(diffs, [2.5, 97.5])
    return point, lo, hi


rows = []

for name, sub in [
    ("Toan bo nguoi dung", w),
    ("Nguoi dung moi", w[w.user_type == "new"]),
    ("Nguoi dung quay lai", w[w.user_type == "returning"])
]:
    r0 = 100 * sub.loc[sub.after == 0, "bought"].mean()
    r1 = 100 * sub.loc[sub.after == 1, "bought"].mean()
    d, lo, hi = boot_diff(user_table(sub))

    rows.append([
        name,
        round(r0, 2),
        round(r1, 2),
        round(d, 2),
        round(lo, 2),
        round(hi, 2)
    ])

res = pd.DataFrame(
    rows,
    columns=[
        "Nhom nguoi dung",
        "Ty le mua truoc (%)",
        "Ty le mua sau (%)",
        "Chenh lech (diem %)",
        "Can duoi KTC 95%",
        "Can tren KTC 95%"
    ]
)

print("\nMuc thay doi ty le mua hang (diem phan tram) va khoang tin cay Bootstrap 95%:")
print(res.to_string(index=False))


# Kiem dinh B: Hoi quy Logistic voi sai so chuan phan cum theo nguoi dung
w["uid"] = pd.factorize(w.user_id)[0]

m = smf.logit(
    "bought ~ after + C(user_type)",
    data=w
).fit(
    disp=0,
    cov_type="cluster",
    cov_kwds={"groups": w["uid"]}
)

or_after = np.exp(m.params["after"])
ci = np.exp(m.conf_int().loc["after"])

print(
    f"\nTy so Odds da dieu chinh (sau so voi truoc, co kiem soat nhom nguoi dung): "
    f"{or_after:.3f}  KTC 95% [{ci[0]:.3f}, {ci[1]:.3f}]  "
    f"Gia tri p = {m.pvalues['after']:.2g}"
)


# Kiem dinh C: So sanh doanh thu hang ngay truoc va sau giai doan bien dong
b = daily.loc[daily.full_date <= "2019-12-14", "revenue"]
a = daily.loc[daily.full_date >= "2019-12-16", "revenue"]

print(
    "\nDoanh thu hang ngay: "
    "Trung binh truoc = %.0f, trung binh sau = %.0f (gap %.2f lan)"
    % (b.mean(), a.mean(), a.mean() / b.mean())
)

print(
    "Kiem dinh Mann-Whitney U (gia thuyet doanh thu sau cao hon truoc):",
    stats.mannwhitneyu(a, b, alternative="greater")
)

print(
    "Kiem dinh t Welch:",
    stats.ttest_ind(a, b, equal_var=False)
)

print("\nHoan tat. Cac bieu do da duoc luu tai:", FIG)