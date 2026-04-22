const express = require('express');
const { Pool } = require('pg');

const app = express();
app.use(express.json());

const pool = new Pool({
  host: process.env.DB_HOST || '10.0.1.10',
  user: process.env.DB_USER || 'backend',
  password: process.env.DB_PASSWORD || 'ContraseñaSegura123',
  database: process.env.DB_NAME || 'academico',
  port: 5432,
});

app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).json({ status: 'ok' });
  } catch (error) {
    res.status(500).json({ status: 'error', message: error.message });
  }
});

app.get('/profesores', async (req, res) => {
  const result = await pool.query('SELECT id, nombre FROM academico.asignaturas ORDER BY id LIMIT 50');
  res.json(result.rows);
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`UFV node service listening on ${PORT}`);
});
