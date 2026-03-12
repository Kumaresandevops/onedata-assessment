const express = require('express');
const app = express();

app.use(express.json());

// In-memory data store
let items = [
  { id: 1, name: 'Item One', value: 100 },
  { id: 2, name: 'Item Two', value: 200 },
];

// Health check
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
});

// GET all items
app.get('/api/items', (req, res) => {
  res.status(200).json({ items, count: items.length });
});

// GET item by ID
app.get('/api/items/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const item = items.find(i => i.id === id);
  if (!item) return res.status(404).json({ error: 'Item not found' });
  res.status(200).json(item);
});

// POST create item
app.post('/api/items', (req, res) => {
  const { name, value } = req.body;
  if (!name || value === undefined) {
    return res.status(400).json({ error: 'name and value are required' });
  }
  const newItem = { id: items.length + 1, name, value };
  items.push(newItem);
  res.status(201).json(newItem);
});

// DELETE item
app.delete('/api/items/:id', (req, res) => {
  const id = parseInt(req.params.id);
  const index = items.findIndex(i => i.id === id);
  if (index === -1) return res.status(404).json({ error: 'Item not found' });
  const deleted = items.splice(index, 1)[0];
  res.status(200).json({ deleted });
});

module.exports = app;

if (require.main === module) {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
}
