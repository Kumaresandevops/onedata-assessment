const request = require('supertest');
const app = require('../src/app');

describe('Health Check', () => {
  test('GET /health returns 200 with status ok', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.timestamp).toBeDefined();
  });
});

describe('GET /api/items', () => {
  test('returns list of items with count', async () => {
    const res = await request(app).get('/api/items');
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body.items)).toBe(true);
    expect(res.body.count).toBeGreaterThan(0);
  });
});

describe('GET /api/items/:id', () => {
  test('returns item when found', async () => {
    const res = await request(app).get('/api/items/1');
    expect(res.statusCode).toBe(200);
    expect(res.body.id).toBe(1);
    expect(res.body.name).toBeDefined();
  });

  test('returns 404 when item not found', async () => {
    const res = await request(app).get('/api/items/9999');
    expect(res.statusCode).toBe(404);
    expect(res.body.error).toBe('Item not found');
  });
});

describe('POST /api/items', () => {
  test('creates a new item successfully', async () => {
    const res = await request(app)
      .post('/api/items')
      .send({ name: 'Test Item', value: 42 });
    expect(res.statusCode).toBe(201);
    expect(res.body.name).toBe('Test Item');
    expect(res.body.value).toBe(42);
    expect(res.body.id).toBeDefined();
  });

  test('returns 400 when name is missing', async () => {
    const res = await request(app)
      .post('/api/items')
      .send({ value: 42 });
    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBeDefined();
  });

  test('returns 400 when value is missing', async () => {
    const res = await request(app)
      .post('/api/items')
      .send({ name: 'No Value Item' });
    expect(res.statusCode).toBe(400);
    expect(res.body.error).toBeDefined();
  });
});

describe('DELETE /api/items/:id', () => {
  test('deletes an existing item', async () => {
    // First create one
    const createRes = await request(app)
      .post('/api/items')
      .send({ name: 'To Delete', value: 0 });
    const id = createRes.body.id;

    const res = await request(app).delete(`/api/items/${id}`);
    expect(res.statusCode).toBe(200);
    expect(res.body.deleted.id).toBe(id);
  });

  test('returns 404 when deleting non-existent item', async () => {
    const res = await request(app).delete('/api/items/9999');
    expect(res.statusCode).toBe(404);
  });
});
