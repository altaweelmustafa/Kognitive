def signed_up(client, email="dash@example.com", password="correct-horse") -> dict:
    """Creates a verified account and returns its Authorization header."""
    body = {"name": "Dash", "gender": "male", "email": email, "password": password}
    code = client.post("/auth/signup", json=body).json()["dev_code"]
    token = client.post("/auth/verify", json={"email": email, "code": code}).json()["token"]
    return {"Authorization": f"Bearer {token}"}
