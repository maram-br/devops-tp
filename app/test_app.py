import pytest
from app import app


@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


def test_index_returns_200(client):
    response = client.get('/')
    assert response.status_code == 200


def test_index_returns_json(client):
    response = client.get('/')
    data = response.get_json()
    assert data is not None
    assert data['status'] == 'ok'
    assert 'message' in data


def test_health_endpoint(client):
    response = client.get('/health')
    assert response.status_code == 200
    data = response.get_json()
    assert data['status'] == 'healthy'


def test_metrics_endpoint(client):
    response = client.get('/metrics')
    assert response.status_code == 200
    assert b'app_request_count_total' in response.data
