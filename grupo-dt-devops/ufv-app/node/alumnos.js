const express = require('express');
const { Pool } = require('pg');
const path = require('path');

const app = express();
app.use(express.json());

const pool = new Pool({
  host: process.env.DB_HOST || '10.0.1.10',
  user: process.env.DB_USER || 'backend_read',
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'academico',
  port: 5432,
  connectionTimeoutMillis: 5000,
});

app.get('/alumnos', (req, res) => {
  res.sendFile(path.join(__dirname, 'alumnos.html'));
});

app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.status(200).json({ status: 'ok', module: 'alumnos' });
  } catch (error) {
    res.status(500).json({ status: 'error', message: error.message });
  }
});

app.get('/alumnos/lista', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT a.id, a.nombre, a.email, COUNT(i.id) AS asignaturas_inscritas
      FROM academico.alumnos a
      LEFT JOIN academico.inscripciones i ON i.alumno_id = a.id
      GROUP BY a.id, a.nombre, a.email
      ORDER BY a.id
      LIMIT 50
    `);
    res.status(200).json(result.rows);
  } catch (error) {
    res.status(500).json({ status: 'error', message: error.message });
  }
});

app.get('/alumnos/asignaturas', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT id, nombre, descripcion, creditos
      FROM academico.asignaturas
      ORDER BY nombre
    `);
    res.status(200).json(result.rows);
  } catch (error) {
    res.status(500).json({ status: 'error', message: error.message });
  }
});

app.get('/alumnos/:id/notas', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(`
      SELECT a.nombre AS asignatura, a.creditos,
             i.fecha_inscripcion, i.nota, i.estado
      FROM academico.inscripciones i
      JOIN academico.asignaturas a ON a.id = i.asignatura_id
      WHERE i.alumno_id = $1
      ORDER BY i.fecha_inscripcion DESC
    `, [id]);
    res.status(200).json(result.rows);
  } catch (error) {
    res.status(500).json({ status: 'error', message: error.message });
  }
});

app.post('/alumnos/inscribir', async (req, res) => {
  try {
    const { alumno_id, asignatura_id } = req.body;
    if (!alumno_id || !asignatura_id) {
      return res.status(400).json({ status: 'error', message: 'alumno_id y asignatura_id son obligatorios' });
    }
    await pool.query(`
      INSERT INTO academico.inscripciones (alumno_id, asignatura_id)
      VALUES ($1, $2)
    `, [alumno_id, asignatura_id]);
    res.status(201).json({ status: 'ok', message: 'Inscripcion realizada correctamente' });
  } catch (error) {
    if (error.code === '23505') {
      return res.status(409).json({ status: 'error', message: 'El alumno ya esta inscrito en esa asignatura' });
    }
    res.status(500).json({ status: 'error', message: error.message });
  }
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`UFV alumnos service listening on ${PORT}`);
});
