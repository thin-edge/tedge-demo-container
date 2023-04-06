def health_topic(service_name: str, child: str = None) -> str:
    """Health topic for the child device"""
    if child:
        return f"tedge/health/{child}/{service_name}"
    return f"tedge/health/{service_name}"


def measurement_topic(child: str = None) -> str:
    """Measurement topic for the child device"""
    if child:
        return f"tedge/measurements/{child}"
    return "tedge/measurements"
