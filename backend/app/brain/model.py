"""Turns a domain's daily scores into a level, a forecast and a trend.

How much history there is decides the method:

    fewer than 3 days   not enough to say anything: forecast = average so far
    3 to 9 days         straight-line fit (least squares)
    10 days or more     ARIMA(1,1,1) with drift, on the last 30 days

In both fitted cases the trend comes from the estimated change per day (the
line's slope, or ARIMA's drift): it must be clearly different from zero given
its own uncertainty (a one-sided 5% test), and big enough to matter. With a
short history the bar is higher, so a couple of lucky days don't read as a
trend.
"""

import warnings
from dataclasses import asdict, dataclass

import numpy as np

MIN_FIT = 3
MIN_ARIMA = 10
WINDOW = 30

# Chance of calling a flat player "improving" (and the same for "declining").
FALSE_ALARM = 0.05
# The change per day must also be at least this share of the current level.
MIN_DAILY_CHANGE = 0.002


@dataclass
class Analysis:
    n: int
    level: float | None  # average of the last three days
    forecast: float | None  # expected score next session
    change_per_day: float | None
    trend: str  # improving | plateau | declining | none
    method: str  # arima | linear | average | none

    def as_dict(self) -> dict:
        d = asdict(self)
        for key in ("level", "forecast", "change_per_day"):
            if d[key] is not None:
                d[key] = round(d[key], 1)
        return d


def _classify(change: float, error: float, level: float, dof: int | None) -> str:
    """`dof` is the line fit's degrees of freedom (Student's t), or None for
    ARIMA, whose estimate is judged against the normal distribution."""
    from scipy import stats

    if error <= 0 or abs(change) < MIN_DAILY_CHANGE * max(level, 1):
        return "plateau"
    required = stats.norm.ppf(1 - FALSE_ALARM) if dof is None else stats.t.ppf(1 - FALSE_ALARM, dof)
    z = change / error
    if z >= required:
        return "improving"
    if z <= -required:
        return "declining"
    return "plateau"


def _linear(y: np.ndarray) -> tuple[float, float, float]:
    """Least-squares line: (next value, slope, slope's standard error)."""
    x = np.arange(len(y), dtype=float)
    slope, intercept = np.polyfit(x, y, 1)
    residuals = y - (slope * x + intercept)
    dof = len(y) - 2
    spread = ((x - x.mean()) ** 2).sum()
    error = float(np.sqrt((residuals**2).sum() / dof / spread)) if dof > 0 else 0.0
    return float(slope * len(y) + intercept), float(slope), error


def _arima(y: np.ndarray) -> tuple[float, float, float]:
    """ARIMA(1,1,1) with drift: (next value, drift, drift's standard error).
    Falls back to simpler orders if the fit fails."""
    from statsmodels.tsa.arima.model import ARIMA

    for order in ((1, 1, 1), (0, 1, 1), (0, 1, 0)):
        try:
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                fit = ARIMA(y, order=order, trend="t").fit()
            forecast, drift, error = float(fit.forecast(1)[0]), float(fit.params[0]), float(fit.bse[0])
            if np.isfinite([forecast, drift, error]).all():
                return forecast, drift, error
        except Exception:  # noqa: BLE001 - any numerical failure: try the next order
            continue
    raise ValueError("ARIMA could not be fitted")


def analyse(scores: list[float]) -> Analysis:
    """`scores` are one per day played, oldest first."""
    n = len(scores)
    if n == 0:
        return Analysis(0, None, None, None, "none", "none")
    y = np.asarray(scores[-WINDOW:], dtype=float)
    level = float(y[-3:].mean())
    if n < MIN_FIT:
        return Analysis(n, level, float(y.mean()), None, "plateau", "average")

    method = "linear"
    if n >= MIN_ARIMA:
        try:
            forecast, change, error = _arima(y)
            method = "arima"
        except ValueError:
            forecast, change, error = _linear(y)
    else:
        forecast, change, error = _linear(y)
    dof = None if method == "arima" else len(y) - 2
    trend = _classify(change, error, level, dof)
    return Analysis(n, level, max(forecast, 0.0), change, trend, method)
