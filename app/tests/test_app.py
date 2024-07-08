import unittest
from app import app, db, User
from datetime import datetime

class BasicTests(unittest.TestCase):

    def setUp(self):
        app.config['TESTING'] = True
        app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
        self.app = app.test_client()
        db.create_all()

    def tearDown(self):
        db.session.remove()
        db.drop_all()

    def test_put_user(self):
        response = self.app.put('/hello/johndoe', json={"dateOfBirth": "2000-01-01"})
        self.assertEqual(response.status_code, 204)
        user = User.query.filter_by(username="johndoe").first()
        self.assertIsNotNone(user)
        self.assertEqual(user.date_of_birth, datetime.strptime("2000-01-01", "%Y-%m-%d").date())

    def test_get_user(self):
        self.app.put('/hello/johndoe', json={"dateOfBirth": "2000-01-01"})
        response = self.app.get('/hello/johndoe')
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertIn("Hello, johndoe! Your birthday is in", data['message'])

if __name__ == "__main__":
    unittest.main()
