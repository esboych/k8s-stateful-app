import os
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime

app = Flask(__name__)

# Read database connection details from environment variables
db_user = os.getenv('DB_USER')
db_password = os.getenv('DB_PASSWORD')
db_host = os.getenv('DB_HOST', 'postgres-postgresql.default.svc.cluster.local')
db_port = os.getenv('DB_PORT', '5432')
db_name = os.getenv('DB_NAME', 'hello_world_db')

app.config['SQLALCHEMY_DATABASE_URI'] = f'postgresql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

class User(db.Model):
    username = db.Column(db.String(80), primary_key=True)
    date_of_birth = db.Column(db.Date, nullable=False)

db.create_all()

@app.route('/hello/<username>', methods=['PUT'])
def save_user(username):
    if not username.isalpha():
        return 'Invalid username', 400

    data = request.get_json()
    date_of_birth = data.get('dateOfBirth')
    try:
        dob = datetime.strptime(date_of_birth, '%Y-%m-%d').date()
        if dob >= datetime.now().date():
            return 'Invalid date of birth', 400
    except ValueError:
        return 'Invalid date format', 400

    user = User.query.filter_by(username=username).first()
    if user:
        user.date_of_birth = dob
    else:
        user = User(username=username, date_of_birth=dob)
    db.session.add(user)
    db.session.commit()

    return '', 204

@app.route('/hello/<username>', methods=['GET'])
def get_greeting(username):
    user = User.query.filter_by(username=username).first()
    if not user:
        return 'User not found', 404

    today = datetime.now().date()
    next_birthday = user.date_of_birth.replace(year=today.year)
    if next_birthday < today:
        next_birthday = next_birthday.replace(year=today.year + 1)

    days_until_birthday = (next_birthday - today).days

    if days_until_birthday == 0:
        message = f'Hello, {username}! Happy birthday!'
    else:
        message = f'Hello, {username}! Your birthday is in {days_until_birthday} day(s)'

    return jsonify(message=message), 200

@app.route('/healthz', methods=['GET'])
def healthz():
    # Liveness probe endpoint
    return jsonify(status='ok'), 200

@app.route('/readiness', methods=['GET'])
def readiness():
    # Readiness probe endpoint, check if the database is reachable
    try:
        db.session.execute('SELECT 1')
        return jsonify(status='ready'), 200
    except Exception as e:
        return jsonify(status='not ready', error=str(e)), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
