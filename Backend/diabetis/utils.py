THRESHOLDS = {
    "Pre-Breakfast": [(200, 'Dangerous'), (130, 'High'), (90, 'Normal'), (70, 'Low')],
    "Post-Breakfast": [(220, 'Dangerous'), (140, 'High'), (90, 'Normal'), (80, 'Low')],
    "Pre-Lunch": [(200, 'Dangerous'), (130, 'High'), (90, 'Normal'), (70, 'Low')],
    "Post-Lunch": [(220, 'Dangerous'), (140, 'High'), (90, 'Normal'), (80, 'Low')],
    "Pre-Dinner": [(200, 'Dangerous'), (130, 'High'), (90, 'Normal'), (70, 'Low')],
    "Post-Dinner": [(220, 'Dangerous'), (140, 'High'), (90, 'Normal'), (80, 'Low')],
    "Random": [(220, 'Dangerous'), (140, 'High'), (90, 'Normal'), (80, 'Low')],  # fallback
}

def classify_glucose(value, time_of_day):
    thresholds = THRESHOLDS.get(time_of_day, THRESHOLDS["Random"])
    for threshold, label in thresholds:
        if value >= threshold:
            return label
    return 'Very Low'
