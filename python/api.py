#!/usr/bin/env python3
import asyncio
import asyncpg
import base64
import json

from aiohttp import web
from aiojobs.aiohttp import atomic, setup

from db_settings import DB_HOST, DB_PORT, DB_NAME

DB_USER = 'http'
DB_PASSWORD = 'http'

PORT = 8000

def parse_authorization_header(value):
    if value[:6] != 'Basic ':
        raise 'Unsupported auth type'
    user_password = base64.b64decode(value[6:].encode()).decode()
    colon_idx = user_password.find(':')
    user = user_password[:colon_idx]
    password = user_password[colon_idx+1:]
    return user, password

async def fetchval_sql(connection, query, *args):
    try:
        return await connection.fetchval(query, *args)
    except:
        raise

async def call_api(connection, user, password, method, path, params):
    return await fetchval_sql(connection, 'select api.api($1, $2, $3, $4, $5)', user, password, method, path, params)

@atomic
async def api(request):
    user = None
    password = None
    body = None
    if 'Authorization' in request.headers:
        user, password = parse_authorization_header(request.headers['Authorization'])
    if request.body_exists:
        body = await request.content.read()

    async with request.app.db_pool.acquire() as connection:
        result = await call_api(connection, user, password, request.method, request.path, body)

    response_body = None
    headers = None
    if 'body' in result:
        response_body = json.dumps(result['body']).encode('utf-8')
    if 'headers' in result:
        headers = result['headers']

    return web.Response(status=result['code'], headers=headers, body=response_body)

def jsonb_encoder(value):
    return b'\x01' + json.dumps(json.loads(value)).encode('utf-8')

def jsonb_decoder(value):
    return json.loads(value[1:].decode('utf-8'))

async def init_connection(conn):
    await conn.set_type_codec('jsonb', encoder=jsonb_encoder, decoder=jsonb_decoder, schema='pg_catalog', format='binary')

async def init_app():
    app = web.Application()
    setup(app)
    app.add_routes(
        [
            web.get('/users', api),
            web.get('/my_users', api),
            web.get('/users/{login}', api),
            web.get('/expenses/{login}', api),
            web.get('/expenses/{login}/{expense}', api),
            web.put('/users/{login}', api),
            web.put('/expenses/{login}/{expense}', api),
            web.delete('/users/{login}', api),
            web.delete('/expenses/{login}/{expense}', api),
        ])
    app.db_pool = await asyncpg.create_pool(host=DB_HOST, port=DB_PORT, user=DB_USER, password=DB_PASSWORD, database=DB_NAME, init=init_connection)
    return app

if __name__ == '__main__':
    loop = asyncio.get_event_loop()
    app = loop.run_until_complete(init_app())
    web.run_app(app, port = PORT)
