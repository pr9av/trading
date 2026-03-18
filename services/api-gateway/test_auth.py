"""
Test suite for API Gateway Authentication
"""

import pytest
from auth import (
    create_token, verify_token, LoginRequest, RegisterRequest,
    TokenResponse, pwd_context
)


def test_password_hashing():
    """Test password hashing."""
    password = "TestPassword123"
    hash1 = pwd_context.hash(password)
    
    # Hashes should be different each time
    hash2 = pwd_context.hash(password)
    assert hash1 != hash2
    
    # But both should verify
    assert pwd_context.verify(password, hash1)
    assert pwd_context.verify(password, hash2)


def test_login_request_validation():
    """Test LoginRequest validation."""
    login = LoginRequest(username="testuser", password="password123")
    assert login.username == "testuser"
    assert login.password == "password123"


def test_register_request_validation():
    """Test RegisterRequest validation."""
    # Valid registration
    register = RegisterRequest(
        username="newuser",
        email="user@example.com",
        password="SecurePass123"
    )
    assert register.username == "newuser"
    assert register.email == "user@example.com"
    assert register.role == "trader"  # Default role

    # Invalid: username too short
    with pytest.raises(ValueError):
        RegisterRequest(
            username="ab",
            email="user@example.com",
            password="SecurePass123"
        )

    # Invalid: password too short
    with pytest.raises(ValueError):
        RegisterRequest(
            username="newuser",
            email="user@example.com",
            password="short"
        )

    # Invalid: password without uppercase
    with pytest.raises(ValueError):
        RegisterRequest(
            username="newuser",
            email="user@example.com",
            password="nouppercase123"
        )

    # Invalid: password without digit
    with pytest.raises(ValueError):
        RegisterRequest(
            username="newuser",
            email="user@example.com",
            password="NoDigitHere"
        )


def test_invalid_role():
    """Test invalid role validation."""
    with pytest.raises(ValueError):
        RegisterRequest(
            username="newuser",
            email="user@example.com",
            password="SecurePass123",
            role="invalid_role"
        )


def test_verify_token_invalid():
    """Test token verification with invalid token."""
    invalid_token = "invalid.token.here"
    result = verify_token(invalid_token)
    assert result is None


def test_create_token_invalid_credentials():
    """Test token creation with invalid credentials."""
    token = create_token("nonexistent_user", "wrong_password")
    assert token is None
