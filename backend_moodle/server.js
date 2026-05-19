import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import fs from 'fs'; // ¡NUEVO! Para leer y guardar archivos
import path from 'path'; // ¡NUEVO! Para las rutas de archivos
import { fileURLToPath } from 'url'; // ¡NUEVO! Necesario para módulos ES

dotenv.config();

// Configuración para usar __dirname en módulos ES modernos
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
app.use(cors());
app.use(express.json({ limit: '50mb' }));

const MOODLE_BASE_URL = process.env.MOODLE_BASE_URL;
const MOODLE_TOKEN = process.env.MOODLE_TOKEN || '';
// NUEVO: Leemos el token de asistencia del .env
const MOODLE_ATTENDANCE_TOKEN = process.env.MOODLE_ATTENDANCE_TOKEN || MOODLE_TOKEN;
const PORT = process.env.PORT || 3000;
const MOODLE_SERVICE = 'moodle_mobile_app';

async function getUserToken(username, password) {
  const url = new URL(`${MOODLE_BASE_URL}/login/token.php`);
  url.searchParams.append('username', username);
  url.searchParams.append('password', password);
  url.searchParams.append('service', MOODLE_SERVICE);

  const response = await fetch(url);
  return await response.json();
}

async function callMoodle(wsfunction, params = {}, tokenOverride = null, method = 'GET') {
  // Si la función es de asistencia, usamos el token especial
  let defaultToken = MOODLE_TOKEN;
  if (wsfunction.startsWith('mod_attendance_')) {
    defaultToken = MOODLE_ATTENDANCE_TOKEN;
  }

  const tokenToUse = tokenOverride || defaultToken;
  const url = new URL(`${MOODLE_BASE_URL}/webservice/rest/server.php`);

  url.searchParams.append('wstoken', tokenToUse);
  url.searchParams.append('moodlewsrestformat', 'json');
  url.searchParams.append('wsfunction', wsfunction);

  // ¡ACÁ ESTÁ LA MAGIA! Le ponemos la máscara a Node.js para engañar a Moodle
  const headers = {
    'User-Agent': 'MoodleMobile'
  };

  if (method === 'GET') {
    Object.entries(params).forEach(([key, value]) => {
      url.searchParams.append(key, value.toString());
    });
    // Se envían los headers camuflados en la petición GET
    const response = await fetch(url, { headers });
    return await response.json();
  } else {
    const form = new URLSearchParams();
    Object.entries(params).forEach(([key, value]) => {
      form.append(key, value.toString());
    });

    // Se envían los headers camuflados en la petición POST
    headers['Content-Type'] = 'application/x-www-form-urlencoded';

    const response = await fetch(url, {
      method: 'POST',
      headers: headers,
      body: form,
    });
    return await response.json();
  }
}

async function uploadFileToDraft({
  token,
  draftItemId,
  fileName,
  mimeType,
  fileBuffer,
}) {
  const uploadUrl = new URL(`${MOODLE_BASE_URL}/webservice/upload.php`);
  uploadUrl.searchParams.append('token', token);
  uploadUrl.searchParams.append('itemid', draftItemId.toString());

  const form = new FormData();
  form.append('token', token);
  form.append('itemid', draftItemId.toString());
  form.append('filepath', '/');
  form.append(
    'file_1',
    new Blob([fileBuffer], { type: mimeType || 'application/octet-stream' }),
    fileName,
  );

  const response = await fetch(uploadUrl, {
    method: 'POST',
    body: form,
  });

  return await response.json();
}

function stripHtml(text = '') {
  return text
    .replace(/<[^>]*>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/\s+/g, ' ')
    .trim();
}

app.get('/', (req, res) => {
  res.json({ message: 'Backend Moodle funcionando' });
});

app.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body ?? {};

    if (!username || !password) {
      return res.status(400).json({ error: 'Faltan credenciales' });
    }

    // 1. Conseguimos el token normal
    const tokenResponse = await getUserToken(username, password);

    if (tokenResponse.error || !tokenResponse.token) {
      return res.status(401).json({
        error: 'Usuario o contraseña incorrectos',
        detail: tokenResponse.error ?? 'No se pudo obtener token',
      });
    }

    // 2. Pedimos los datos del usuario usando ese token normal
    const siteInfo = await callMoodle(
      'core_webservice_get_site_info',
      {},
      tokenResponse.token,
    );

    if (siteInfo.exception || !siteInfo.userid) {
      return res.status(401).json({
        error: 'Token inválido o servicio mal configurado',
        detail: siteInfo.message ?? 'No se pudo validar el token',
        tokenResponse,
        siteInfo,
      });
    }

    // ¡ACÁ ESTÁ EL CAMBIO! Le extraemos la llave privada (privatetoken) a Moodle.
    // Viene escondida adentro de siteInfo.
    const privateToken = siteInfo.userprivateaccesskey || '';

    res.json({
      token: tokenResponse.token,
      privatetoken: privateToken, // Mandamos la llave mágica a la app
      user: {
        userid: siteInfo.userid,
        username: siteInfo.username,
        fullname: siteInfo.fullname,
        firstname: siteInfo.firstname,
        lastname: siteInfo.lastname,
      },
    });
  } catch (error) {
    res.status(500).json({
      error: 'Error al iniciar sesión',
      detail: error.message,
    });
  }
});

app.get('/site-info', async (req, res) => {
  try {
    const token = req.query.token?.toString() || MOODLE_TOKEN;
    const data = await callMoodle('core_webservice_get_site_info', {}, token);
    res.json(data);
  } catch (error) {
    res.status(500).json({
      error: 'Error al consultar Moodle',
      detail: error.message,
    });
  }
});

app.get('/debug-site-info', async (req, res) => {
  try {
    const token = req.query.token?.toString() || MOODLE_TOKEN;
    const siteInfo = await callMoodle(
      'core_webservice_get_site_info',
      {},
      token,
    );
    res.json(siteInfo);
  } catch (error) {
    res.status(500).json({
      error: 'Error al depurar site info',
      detail: error.message,
    });
  }
});

app.get('/my-courses', async (req, res) => {
  try {
    const token = req.query.token?.toString() || MOODLE_TOKEN;

    const siteInfo = await callMoodle(
      'core_webservice_get_site_info',
      {},
      token,
    );

    if (!siteInfo.userid) {
      return res.status(400).json({
        error: 'No se pudo obtener el userid del usuario',
        siteInfo,
      });
    }

    const result = await callMoodle(
      'core_enrol_get_users_courses',
      { userid: siteInfo.userid },
      token,
    );

    const courses = (result || []).map((course) => ({
      id: course.id,
      fullname: course.fullname,
      shortname: course.shortname,
      roleid: course.roleid,
      role: course.rolename,
    }));

    res.json(courses);
  } catch (error) {
    res.status(500).json({
      error: 'Error al consultar cursos',
      detail: error.message,
    });
  }
});

app.get('/course-detail', async (req, res) => {
  try {
    const token = req.query.token?.toString() || MOODLE_TOKEN;
    const courseid = req.query.courseid?.toString();

    if (!courseid) {
      return res.status(400).json({ error: 'Falta courseid' });
    }

    const result = await callMoodle(
      'core_course_get_courses_by_field',
      {
        field: 'id',
        value: courseid,
      },
      token,
    );

    const course = (result.courses || [])[0] || {};
    res.json(course);
  } catch (error) {
    res.status(500).json({
      error: 'Error al consultar detalle del curso',
      detail: error.message,
    });
  }
});

app.get('/course-contents', async (req, res) => {
  try {
    const token = req.query.token?.toString() || MOODLE_TOKEN;
    const courseid = req.query.courseid?.toString();

    if (!courseid) {
      return res.status(400).json({ error: 'Falta courseid' });
    }

    const result = await callMoodle(
      'core_course_get_contents',
      { courseid },
      token,
    );

    res.json(result || []);
  } catch (error) {
    res.status(500).json({
      error: 'Error al consultar contenidos del curso',
      detail: error.message,
    });
  }
});

app.get('/course-participants', async (req, res) => {
  try {
    const token = req.query.token?.toString() || MOODLE_TOKEN;
    const courseid = req.query.courseid?.toString();

    if (!courseid) {
      return res.status(400).json({ error: 'Falta courseid' });
    }

    const result = await callMoodle(
      'core_enrol_get_enrolled_users',
      { courseid },
      token,
    );

    const participants = (result || []).map((user) => ({
      id: user.id,
      fullname: user.fullname,
      email: user.email,
      roles: (user.roles || []).map((r) => r.shortname || r.name).join(', '),
    }));

    res.json(participants);
  } catch (error) {
    res.status(500).json({
      error: 'Error al consultar participantes',
      detail: error.message,
    });
  }
});

app.get('/assignment-detail', async (req, res) => {
  try {
    const token = req.query.token?.toString() || MOODLE_TOKEN;
    const courseid = req.query.courseid?.toString();
    const cmid = req.query.cmid?.toString();

    if (!courseid || !cmid) {
      return res.status(400).json({ error: 'Faltan courseid o cmid' });
    }

    const result = await callMoodle(
      'mod_assign_get_assignments',
      { 'courseids[0]': courseid },
      token,
    );

    const courses = result.courses || [];
    const assignments = courses.flatMap((course) => course.assignments || []);
    const assignment =
      assignments.find((item) => item.cmid?.toString() === cmid) || null;

    if (!assignment) {
      return res.status(404).json({ error: 'No se encontró la tarea' });
    }

    res.json({
      id: assignment.id,
      cmid: assignment.cmid,
      course: assignment.course,
      name: assignment.name,
      intro: assignment.intro || '',
      introformat: assignment.introformat,
      duedate: assignment.duedate,
      allowsubmissionsfromdate: assignment.allowsubmissionsfromdate,
      cutoffdate: assignment.cutoffdate,
      gradingduedate: assignment.gradingduedate,
      submissiontypes: assignment.configs || [],
      nosubmissions: assignment.nosubmissions,
      submissiondrafts: assignment.submissiondrafts,
      sendnotifications: assignment.sendnotifications,
      sendlatenotifications: assignment.sendlatenotifications,
      sendstudentnotifications: assignment.sendstudentnotifications,
    });
  } catch (error) {
    res.status(500).json({
      error: 'Error al consultar detalle de la tarea',
      detail: error.message,
    });
  }
});

app.get('/assignment-status', async (req, res) => {
  try {
    const token = req.query.token?.toString() || MOODLE_TOKEN;
    const assignid = req.query.assignid?.toString();

    if (!assignid) {
      return res.status(400).json({ error: 'Falta assignid' });
    }

    const result = await callMoodle(
      'mod_assign_get_submission_status',
      { assignid },
      token,
    );

    const lastAttempt = result.lastattempt || {};
    const submission = lastAttempt.submission || {};
    const feedback = lastAttempt.feedback || {};
    const submissionStatus = result.submissionstatus || submission.status || 'new';

    res.json({
      gradestatus: result.gradestatus || '',
      submissionstatus: submissionStatus,
      submitted: submissionStatus === 'submitted',
      canedit: result.canedit ?? false,
      cansubmit: result.cansubmit ?? false,
      locked: result.locked ?? false,
      graded: result.graded ?? false,
      duedate: result.duedate ?? null,
      extensionduedate: result.extensionduedate ?? null,
      lastattempt: lastAttempt,
      submission,
      feedback,
      warnings: result.warnings || [],
    });
  } catch (error) {
    res.status(500).json({
      error: 'Error al consultar estado de la entrega',
      detail: error.message,
    });
  }
});

// ¡ACÁ ESTÁ EL PLAN B PARA LAS ENTREGAS DE TAREAS!
app.post('/assignment-submit', async (req, res) => {
  try {
    const {
      token,
      assignid,
      fileName,
      fileBase64,
      mimeType,
      comment = '',
      finalSubmit = true,
    } = req.body ?? {};

    if (!token || !assignid || !fileName || !fileBase64) {
      return res.status(400).json({
        error: 'Faltan token, assignid, fileName o fileBase64',
      });
    }

    let draftItemId = await callMoodle(
      'core_files_get_unused_draft_itemid',
      {},
      token,
    );

    if (typeof draftItemId === 'object' && draftItemId !== null && draftItemId.itemid) {
      draftItemId = draftItemId.itemid;
    }

    if (!draftItemId || typeof draftItemId !== 'number') {
      return res.status(500).json({
        error: 'No se pudo obtener draft item id',
        detail: draftItemId,
      });
    }

    const cleanBase64 = fileBase64.includes(',')
      ? fileBase64.split(',').pop()
      : fileBase64;

    const fileBuffer = Buffer.from(cleanBase64, 'base64');

    const uploadResult = await uploadFileToDraft({
      token,
      draftItemId,
      fileName,
      mimeType,
      fileBuffer,
    });

    if (!Array.isArray(uploadResult) || uploadResult.length === 0) {
      return res.status(500).json({
        error: 'No se pudo subir el archivo al draft area',
        detail: uploadResult,
      });
    }

    if (uploadResult[0]?.error) {
      return res.status(500).json({
        error: 'Moodle rechazó la subida del archivo',
        detail: uploadResult,
      });
    }

    const saveParams = { assignmentid: assignid };

    if (draftItemId) {
      saveParams['plugindata[files_filemanager]'] = draftItemId;
    }

    const hasComment = comment && comment.trim() !== '';
    if (hasComment) {
      saveParams['plugindata[onlinetext_editor][text]'] = comment;
      saveParams['plugindata[onlinetext_editor][format]'] = 1;
      saveParams['plugindata[onlinetext_editor][itemid]'] = draftItemId;
    }

    let saveResult = await callMoodle(
      'mod_assign_save_submission',
      saveParams,
      token,
      'POST'
    );

    // ¡EL TRUCO SALVAVIDAS!
    // Si Moodle dice "parámetro no válido", es porque el profesor no habilitó la opción
    // de aceptar "Texto en línea" en esta tarea. Entonces reintentamos SIN el comentario.
    if (saveResult?.exception === 'invalid_parameter_exception' || saveResult?.exception === 'dml_write_exception') {
      console.warn('⚠️ Moodle rechazó el guardado completo. Intentando modo compatibilidad (Solo archivo)...');
      if (hasComment) {
        delete saveParams['plugindata[onlinetext_editor][text]'];
        delete saveParams['plugindata[onlinetext_editor][format]'];
        delete saveParams['plugindata[onlinetext_editor][itemid]'];

        saveResult = await callMoodle(
          'mod_assign_save_submission',
          saveParams,
          token,
          'POST'
        );
      }
    }

    if (saveResult?.exception) {
      return res.status(500).json({
        error: 'No se pudo guardar la entrega',
        detail: saveResult,
      });
    }

    let submitResult = null;

    if (finalSubmit) {
      submitResult = await callMoodle(
        'mod_assign_submit_for_grading',
        { assignmentid: assignid, acceptsubmissionstatement: 1 },
        token,
        'POST'
      );

      if (submitResult?.exception) {
        return res.status(500).json({
          error: 'Se guardó el archivo pero no se pudo enviar para calificación',
          detail: submitResult,
          saveResult,
        });
      }
    }

    res.json({
      ok: true,
      message: finalSubmit
        ? 'Entrega enviada correctamente'
        : 'Archivo guardado en borrador correctamente',
      draftItemId,
      uploadResult,
      saveResult,
      submitResult,
    });
  } catch (error) {
    res.status(500).json({
      error: 'Error al enviar la tarea',
      detail: error.message,
    });
  }
});

// --- RUTAS NUEVAS PARA FOROS ---

app.get('/forum-discussions', async (req, res) => {
  try {
    const token = req.query.token?.toString() || MOODLE_TOKEN;
    const forumid = req.query.forumid?.toString();

    if (!forumid) {
      return res.status(400).json({ error: 'Falta forumid' });
    }

    const result = await callMoodle(
      'mod_forum_get_forum_discussions',
      { forumid },
      token
    );

    res.json(result.discussions || []);
  } catch (error) {
    res.status(500).json({
      error: 'Error al consultar discusiones del foro',
      detail: error.message,
    });
  }
});

app.get('/forum-posts', async (req, res) => {
  try {
    const token = req.query.token?.toString() || MOODLE_TOKEN;
    const discussionid = req.query.discussionid?.toString();

    if (!discussionid) {
      return res.status(400).json({ error: 'Falta discussionid' });
    }

    const result = await callMoodle(
      'mod_forum_get_forum_discussion_posts',
      { discussionid },
      token
    );

    res.json(result.posts || []);
  } catch (error) {
    res.status(500).json({
      error: 'Error al consultar mensajes de la discusión',
      detail: error.message,
    });
  }
});

// --- RUTAS PARA CALIFICACIONES ---

app.get('/course-grades', async (req, res) => {
  try {
    const token = req.query.token?.toString() || MOODLE_TOKEN;
    const courseid = req.query.courseid?.toString();
    let userid = req.query.userid?.toString();

    if (!courseid) {
      return res.status(400).json({ error: 'Falta courseid' });
    }

    if (!userid) {
      const siteInfo = await callMoodle('core_webservice_get_site_info', {}, token);
      if (!siteInfo.userid) {
        return res.status(401).json({ error: 'No se pudo obtener el userid del token' });
      }
      userid = siteInfo.userid.toString();
    }

    const result = await callMoodle(
      'gradereport_user_get_grade_items',
      { courseid, userid },
      token
    );

    const userGrades = result.usergrades && result.usergrades.length > 0
      ? result.usergrades[0].gradeitems
      : [];

    // ==============================================================================
    // ¡NUEVA INYECCIÓN NINJA! Buscamos el porcentaje real de la Asistencia y lo metemos a la fuerza
    // ==============================================================================
    let attendancePercentage = null;
    let attendanceInstanceId = null;

    // Buscamos si hay un módulo de asistencia en el curso
    const contents = await callMoodle('core_course_get_contents', { courseid }, MOODLE_TOKEN);
    if (!contents.exception && Array.isArray(contents)) {
      for (const section of contents) {
        if (section.modules && Array.isArray(section.modules)) {
          const attendanceModule = section.modules.find(mod => mod.modname === 'attendance');
          if (attendanceModule) {
            attendanceInstanceId = attendanceModule.instance;
            break;
          }
        }
      }
    }

    // Si encontramos el módulo, le preguntamos a Moodle el porcentaje de este alumno específico
    if (attendanceInstanceId) {
       const sessionsData = await callMoodle(
         'mod_attendance_get_sessions',
         { attendanceid: attendanceInstanceId },
         MOODLE_ATTENDANCE_TOKEN
       );

       if (!sessionsData?.exception && Array.isArray(sessionsData)) {
           const sessionPromises = sessionsData.map(async (sess) => {
               return await callMoodle('mod_attendance_get_session', { sessionid: sess.id }, MOODLE_ATTENDANCE_TOKEN);
           });

           const details = await Promise.all(sessionPromises);

           let points = 0;
           let maxPoints = 0;

           details.forEach(detail => {
               if (!detail || detail.exception) return;

               let validStatuses = detail.statuses || [];
               if (validStatuses.length === 0 && detail.session && detail.session.statuses) validStatuses = detail.session.statuses;
               if (validStatuses.length === 0 && detail.statusset && detail.statusset.statuses) validStatuses = detail.statusset.statuses;

               let myLog = null;
               if (detail.attendance_log && Array.isArray(detail.attendance_log)) {
                   myLog = detail.attendance_log.find(log => log.studentid == userid);
               }
               if (!myLog && detail.users && Array.isArray(detail.users)) {
                   const studentObj = detail.users.find(u => u.id == userid);
                   if (studentObj && studentObj.attendance_log) {
                       myLog = Array.isArray(studentObj.attendance_log) ? studentObj.attendance_log[0] : studentObj.attendance_log;
                   }
               }

               if (myLog) {
                   const sId = parseInt(myLog.statusid, 10);
                   const statInfo = validStatuses.find(s => s.id === sId);
                   if (statInfo && statInfo.grade !== undefined) {
                       points += parseFloat(statInfo.grade);
                   } else {
                       points += 2;
                   }
               }
               maxPoints += 2;
           });

           if (maxPoints > 0) {
               let perc = Math.round((points / maxPoints) * 100);
               attendancePercentage = (perc > 100 ? 100 : perc) + " %";
           }
       }
    }

    // Buscamos la fila de asistencia en el JSON de calificaciones y le inyectamos la nota calculada
    if (attendancePercentage) {
      for (let i = 0; i < userGrades.length; i++) {
        if (userGrades[i].itemmodule === 'attendance') {
           // Evaluamos si el profesor YA puso una nota oficial en el boletín
           const raw = userGrades[i].graderaw;
           const gradeFmt = (userGrades[i].gradeformatted || '-').toString().trim();
           const percFmt = (userGrades[i].percentageformatted || '-').toString().trim();

           const tieneNotaOficial = raw !== null ||
               (gradeFmt !== '-' && gradeFmt !== '' && gradeFmt !== 'null') ||
               (percFmt !== '-' && percFmt !== '' && percFmt !== 'null');

           // Si Moodle lo manda vacío, inyectamos nuestro cálculo ninja
           if (!tieneNotaOficial) {
               userGrades[i].percentageformatted = attendancePercentage;
               // Le inventamos un graderaw dummy para que Flutter entienda que ya fue "Calificado"
               userGrades[i].graderaw = 1;
           }
        }
      }
    }
    // ==============================================================================

    res.json(userGrades);
  } catch (error) {
    res.status(500).json({
      error: 'Error al consultar calificaciones del curso',
      detail: error.message,
    });
  }
});


// --- RUTAS NUEVAS: PANEL DOCENTE ---

// 1. Obtener todas las entregas de una tarea y cruzarlas con los alumnos
app.get('/teacher/assignment-submissions', async (req, res) => {
  try {
    const token = req.query.token?.toString() || MOODLE_TOKEN;
    const assignid = req.query.assignid?.toString();
    const courseid = req.query.courseid?.toString();

    if (!assignid) {
      return res.status(400).json({ error: 'Falta assignid' });
    }

    // Pedimos las entregas
    const submissionsData = await callMoodle(
      'mod_assign_get_submissions',
      { 'assignmentids[0]': assignid },
      token
    );

    // Pedimos las notas ya puestas
    const gradesData = await callMoodle(
      'mod_assign_get_grades',
      { 'assignmentids[0]': assignid },
      token
    );

    const submissions = submissionsData.assignments?.[0]?.submissions || [];
    const grades = gradesData.assignments?.[0]?.grades || [];

    // ¡NUEVO!: Pedimos la info de la tarea para saber el puntaje máximo real
    let realMaxGrade = 100; // Por defecto
    if (courseid) {
      const allTasksData = await callMoodle(
        'mod_assign_get_assignments',
        { 'courseids[0]': courseid },
        token
      );
      if (allTasksData.courses && allTasksData.courses.length > 0) {
        const tasks = allTasksData.courses[0].assignments || [];
        const specificTask = tasks.find(t => t.id.toString() === assignid);
        if (specificTask && specificTask.grade !== undefined) {
           realMaxGrade = parseInt(specificTask.grade, 10);
        }
      }
    }

    // Recolectamos IDs de los alumnos que entregaron
    const userIds = submissions.map(sub => sub.userid);
    let usersMap = {};

    // ¡EL TRUCO DE ASISTENCIA!
    if (userIds.length > 0 && courseid) {
      const enrolledUsers = await callMoodle('core_enrol_get_enrolled_users', { courseid: courseid }, MOODLE_TOKEN);

      if (!enrolledUsers.exception && Array.isArray(enrolledUsers)) {
        enrolledUsers.forEach(user => {
          usersMap[user.id] = user.fullname;
        });
      }
    } else if (userIds.length > 0) {
        const fallbackParams = {};
        userIds.forEach((id, index) => {
          fallbackParams[`criteria[${index}][key]`] = 'id';
          fallbackParams[`criteria[${index}][value]`] = id;
        });
        const usersData = await callMoodle('core_user_get_users', fallbackParams, MOODLE_TOKEN);
        if (!usersData.exception && usersData.users) {
          usersData.users.forEach(user => {
            usersMap[user.id] = user.fullname;
          });
        }
    }

    // Armamos la respuesta
    const resultList = submissions.map(sub => {
      const gradeInfo = grades.find(g => g.userid === sub.userid);

      let fileName = '';
      let fileUrl = '';
      if (sub.plugins) {
        const filePlugin = sub.plugins.find(p => p.type === 'file');
        if (filePlugin && filePlugin.fileareas && filePlugin.fileareas[0] && filePlugin.fileareas[0].files && filePlugin.fileareas[0].files.length > 0) {
           fileName = filePlugin.fileareas[0].files[0].filename;
           fileUrl = filePlugin.fileareas[0].files[0].fileurl;
        }
      }

      return {
        userid: sub.userid,
        studentName: usersMap[sub.userid] || `Estudiante ID: ${sub.userid}`,
        status: sub.status,
        fileName: fileName,
        fileUrl: fileUrl,
        grade: gradeInfo ? gradeInfo.grade : null,
        comment: gradeInfo ? stripHtml(gradeInfo.gradefordisplay || '') : '',
        reviewed: !!gradeInfo,
      };
    });

    // Enviamos un objeto que incluya la lista de alumnos Y la nota máxima real
    res.json({
      maxGrade: realMaxGrade,
      submissions: resultList
    });

  } catch (error) {
    res.status(500).json({
      error: 'Error al consultar las entregas de la tarea',
      detail: error.message,
    });
  }
});

// 2. Guardar la nota y el feedback de un alumno
app.post('/teacher/assignment-grade', async (req, res) => {
  try {
    const { token, assignid, userid, grade, comment } = req.body ?? {};

    if (!token || !assignid || !userid || grade === undefined) {
      return res.status(400).json({ error: 'Faltan datos obligatorios (token, assignid, userid, grade)' });
    }

    const params = {
      assignmentid: assignid,
      userid,
      grade: grade.toString(), // Moodle exige que la nota se mande como string o float
      attemptnumber: -1, // -1 significa "el intento actual"
      addattempt: 0,
      workflowstate: 'graded',
      applytoall: 0,
    };

    // Si el profe escribió un comentario, lo agregamos como "feedback en línea"
    if (comment && comment.trim() !== '') {
      params['plugindata[assignfeedbackcomments_editor][text]'] = comment;
      params['plugindata[assignfeedbackcomments_editor][format]'] = 1;
    }

    const result = await callMoodle(
      'mod_assign_save_grade',
      params,
      token,
      'POST'
    );

    if (result === null || result === '') {
       // mod_assign_save_grade suele devolver null si fue exitoso
       return res.json({ ok: true, message: 'Calificación guardada correctamente' });
    } else if (result?.exception) {
      return res.status(500).json({
        error: 'No se pudo guardar la calificación en Moodle',
        detail: result,
      });
    }

    res.json({ ok: true, result });
  } catch (error) {
    res.status(500).json({
      error: 'Error al procesar la calificación',
      detail: error.message,
    });
  }
});

// --- RUTAS NUEVAS PARA ASISTENCIA (mod_attendance) ---

// 1. Obtener todas las sesiones de asistencia de un curso
app.get('/attendance-sessions', async (req, res) => {
  try {
    const courseid = req.query.courseid?.toString();
    const userToken = req.query.token?.toString(); // Usamos el token de la App (del alumno/profe)

    if (!courseid) {
      return res.status(400).json({ error: 'Falta courseid' });
    }

    // Usamos el token del USUARIO LOGUEADO para entrar al curso y que no nos rechace Moodle
    const contents = await callMoodle(
      'core_course_get_contents',
      { courseid },
      userToken || MOODLE_TOKEN
    );

    if (contents.exception) {
        return res.status(500).json({ error: 'Error al leer el curso', detail: contents });
    }

    // Buscamos el ID mágico del módulo de asistencia
    let attendanceId = null;
    if (Array.isArray(contents)) {
      for (const section of contents) {
        if (section.modules && Array.isArray(section.modules)) {
          const attendanceModule = section.modules.find(mod => {
            if (mod.modname === 'attendance') return true;

            // Si no es el plugin oficial, buscamos por el título que le puso el profesor
            const modNameStr = (mod.name || '').toLowerCase();
            return modNameStr.includes('asistencia') ||
                   modNameStr.includes('asitencia') || // Atrapamos el error de tipeo
                   modNameStr.includes('attendance') ||
                   modNameStr.includes('presentismo');
          });

          if (attendanceModule) {
            attendanceId = attendanceModule.instance;
            break;
          }
        }
      }
    }

    if (!attendanceId) {
      return res.json([]); // No hay asistencia
    }

    // AHORA SÍ: Usamos explícitamente el token NUESTRO (el maestro) para traer las clases
    const sessionsResult = await callMoodle(
      'mod_attendance_get_sessions',
      { attendanceid: attendanceId },
      MOODLE_ATTENDANCE_TOKEN
    );

    if (sessionsResult && sessionsResult.exception) {
       return res.status(500).json({ error: 'Error al obtener sesiones', detail: sessionsResult });
    }

    const sessions = (sessionsResult || []).map((sess) => ({
      id: sess.id,
      attendanceid: attendanceId,
      groupId: sess.groupid,
      sessdate: sess.sessdate,
      duration: sess.duration,
      description: sess.description || 'Clase regular',
      statusset: sess.statusset,
      lasttaken: sess.lasttaken,
      studentscanmark: sess.studentscanmark,
    }));

    res.json(sessions);
  } catch (error) {
    res.status(500).json({
      error: 'Error al consultar las sesiones de asistencia',
      detail: error.message,
    });
  }
});

// 2. (SOLO DOCENTES) Obtener la lista de alumnos para una sesión específica
app.get('/attendance-session-detail', async (req, res) => {
  try {
    const sessionid = req.query.sessionid?.toString();

    if (!sessionid) {
      return res.status(400).json({ error: 'Falta sessionid' });
    }

    // Usamos la llave maestra
    const result = await callMoodle(
      'mod_attendance_get_session',
      { sessionid },
      MOODLE_ATTENDANCE_TOKEN
    );

    if (result.exception) {
      return res.status(500).json({ error: 'Error de Moodle', detail: result });
    }

    // ¡EL ARREGLO PARA QUE LOS ESTADOS NO SEAN 0! Extracción agresiva
    let extractedStatuses = result.statuses || [];
    if (extractedStatuses.length === 0 && result.session && result.session.statuses) {
       extractedStatuses = result.session.statuses;
    }
    if (extractedStatuses.length === 0 && result.statusset && result.statusset.statuses) {
       extractedStatuses = result.statusset.statuses;
    }

    res.json({
      users: result.users || [],
      statuses: extractedStatuses,
    });
  } catch (error) {
    res.status(500).json({
      error: 'Error al consultar el detalle de la sesión',
      detail: error.message,
    });
  }
});

// 3. (SOLO DOCENTES) Guardar la lista pasada por el profesor
app.post('/attendance-submit', async (req, res) => {
  try {
    const { sessionid, studentData } = req.body ?? {};

    if (!sessionid || !studentData || !Array.isArray(studentData)) {
      return res.status(400).json({ error: 'Faltan datos obligatorios' });
    }

    // --- SALVAVIDAS ---
    const sessionInfo = await callMoodle('mod_attendance_get_session', { sessionid }, MOODLE_ATTENDANCE_TOKEN);

    let validStatuses = sessionInfo.statuses || [];
    if (validStatuses.length === 0 && sessionInfo.session && sessionInfo.session.statuses) {
       validStatuses = sessionInfo.session.statuses;
    }
    if (validStatuses.length === 0 && sessionInfo.statusset && sessionInfo.statusset.statuses) {
       validStatuses = sessionInfo.statusset.statuses;
    }

    let fallbackStatusId = 0;
    if (validStatuses.length > 0) {
       const presentStatus = validStatuses.find(s => (s.acronym || '').toUpperCase() === 'P') || validStatuses[0];
       fallbackStatusId = presentStatus.id;
    }

    // --- OBTENEMOS EL ID DEL DUEÑO DEL TOKEN (El Administrador/Profesor) ---
    const adminSiteInfo = await callMoodle('core_webservice_get_site_info', {}, MOODLE_ATTENDANCE_TOKEN);
    const takenById = adminSiteInfo.userid || 1; // Si falla, usamos el ID 1 (el admin principal por defecto)

    // --- CORRECCIÓN SINGULAR FINAL BLINDADA ---
    for (const data of studentData) {
      let sId = parseInt(data.statusid, 10);
      if (isNaN(sId) || sId === 0) {
        sId = fallbackStatusId;
      }

      let acronym = 'P';
      const stat = validStatuses.find(s => s.id === sId);
      if (stat && stat.acronym) {
        acronym = stat.acronym;
      }

      const params = {
        sessionid: sessionid,
        studentid: data.studentid,
        takenbyid: takenById,  // ¡AQUÍ ESTÁ EL CAMBIO CLAVE! Usamos un usuario real.
        statusid: sId,
        statusset: acronym
      };

      const result = await callMoodle(
        'mod_attendance_update_user_status', // Función en singular
        params,
        MOODLE_ATTENDANCE_TOKEN,
        'POST'
      );

      if (result?.exception) {
        throw new Error(JSON.stringify(result));
      }
    }

    res.json({ ok: true, message: 'Asistencia guardada correctamente' });
  } catch (error) {
    res.status(500).json({
      error: 'Error al enviar la asistencia',
      detail: error.message,
    });
  }
});

// 4. (SOLO ALUMNOS) Ver su propio porcentaje y estado de asistencia
app.get('/attendance-my-status', async (req, res) => {
  try {
    const courseid = req.query.courseid?.toString();
    const userToken = req.query.token?.toString();
    let userid = req.query.userid?.toString();

    if (!courseid) {
      return res.status(400).json({ error: 'Falta courseid' });
    }

    // Entramos con el token del alumno
    const contents = await callMoodle('core_course_get_contents', { courseid }, userToken || MOODLE_TOKEN);
    let attendanceId = null;

    if (!contents.exception && Array.isArray(contents)) {
        for (const section of contents) {
          if (section.modules && Array.isArray(section.modules)) {
            const attendanceModule = section.modules.find(mod => {
              if (mod.modname === 'attendance') return true;

              // Si no es el plugin oficial, buscamos por el título que le puso el profesor
              const modNameStr = (mod.name || '').toLowerCase();
              return modNameStr.includes('asistencia') ||
                     modNameStr.includes('asitencia') ||
                     modNameStr.includes('attendance') ||
                     modNameStr.includes('presentismo');
            });

            if (attendanceModule) {
              attendanceId = attendanceModule.instance;
              break;
            }
          }
        }
    }

    if (!attendanceId) {
      return res.json({ error: 'No hay módulo de asistencia en este curso' });
    }

    let finalUserId = userid;
    if (!finalUserId) {
        const siteInfo = await callMoodle('core_webservice_get_site_info', {}, userToken || MOODLE_TOKEN);
        finalUserId = siteInfo.userid;
    }

    finalUserId = parseInt(finalUserId, 10);

    // --- EL PLAN MAESTRO: Como la función inventada de Moodle fallaba,
    // descargamos todas las sesiones con la llave maestra y buscamos al alumno manualmente ---

    const sessionsData = await callMoodle(
      'mod_attendance_get_sessions',
      { attendanceid: attendanceId },
      MOODLE_ATTENDANCE_TOKEN
    );

    if (sessionsData && sessionsData.exception) {
       return res.status(500).json({ error: 'Error al obtener sesiones', detail: sessionsData });
    }

    const sessionsList = Array.isArray(sessionsData) ? sessionsData : [];

    // Traemos los detalles de todas las sesiones en paralelo (súper rápido en Node)
    const sessionPromises = sessionsList.map(async (sess) => {
       const detail = await callMoodle('mod_attendance_get_session', { sessionid: sess.id }, MOODLE_ATTENDANCE_TOKEN);
       return { sessionid: sess.id, detail: detail };
    });

    const details = await Promise.all(sessionPromises);

    let myStatuses = [];
    let points = 0;
    let maxPoints = 0;

    details.forEach(item => {
       const detail = item.detail;
       if (!detail || detail.exception) return;

       let validStatuses = detail.statuses || [];
       if (validStatuses.length === 0 && detail.session && detail.session.statuses) validStatuses = detail.session.statuses;
       if (validStatuses.length === 0 && detail.statusset && detail.statusset.statuses) validStatuses = detail.statusset.statuses;

       let myLog = null;
       // A veces Moodle manda el log de asistencia directo en la raíz de la sesión
       if (detail.attendance_log && Array.isArray(detail.attendance_log)) {
           myLog = detail.attendance_log.find(log => log.studentid === finalUserId);
       }

       // Y a veces lo mete adentro del array de usuarios de esa clase
       if (!myLog && detail.users && Array.isArray(detail.users)) {
           const studentObj = detail.users.find(u => u.id === finalUserId);
           if (studentObj && studentObj.attendance_log) {
               if (Array.isArray(studentObj.attendance_log)) {
                   myLog = studentObj.attendance_log[0];
               } else {
                   myLog = studentObj.attendance_log;
               }
           }
       }

       // Si lo encontramos en la lista, guardamos su estado exacto
       if (myLog) {
           const sId = parseInt(myLog.statusid, 10);
           const statInfo = validStatuses.find(s => s.id === sId);
           const description = statInfo ? statInfo.description : (myLog.statusset || 'Presente');

           myStatuses.push({
              sessionid: item.sessionid,
              description: description
           });

           if (statInfo && statInfo.grade !== undefined) {
               points += parseFloat(statInfo.grade);
           } else {
               points += 2; // Puntaje base si no hay info
           }
       }
       maxPoints += 2;
    });

    let percentage = maxPoints > 0 ? Math.round((points / maxPoints) * 100) : 0;
    if (percentage > 100) percentage = 100;

    // ¡Le mandamos a tu app de Flutter el JSON idéntico al que esperaba leer!
    res.json({
       summary: { percentage: percentage.toString() },
       statuses: myStatuses
    });

  } catch (error) {
    res.status(500).json({
      error: 'Error al consultar la asistencia del alumno',
      detail: error.message,
    });
  }
});

// 5. (NUEVO - ALUMNOS) Auto-registrar asistencia
app.post('/student-attendance-submit', async (req, res) => {
  try {
    const { sessionid, studentid, statusid } = req.body ?? {};

    // CORRECCIÓN: statusid puede ser 0, así que validamos con !== undefined en vez de !statusid
    if (!sessionid || !studentid || statusid === undefined) {
      return res.status(400).json({ error: 'Faltan datos obligatorios para auto-registro' });
    }

    // --- SALVAVIDAS para el auto-registro del alumno ---
    const sessionInfo = await callMoodle('mod_attendance_get_session', { sessionid }, MOODLE_ATTENDANCE_TOKEN);

    let validStatuses = sessionInfo.statuses || [];
    if (validStatuses.length === 0 && sessionInfo.session && sessionInfo.session.statuses) {
       validStatuses = sessionInfo.session.statuses;
    }
    if (validStatuses.length === 0 && sessionInfo.statusset && sessionInfo.statusset.statuses) {
       validStatuses = sessionInfo.statusset.statuses;
    }

    let fallbackStatusId = 0;
    if (validStatuses.length > 0) {
       const presentStatus = validStatuses.find(s => (s.acronym || '').toUpperCase() === 'P') || validStatuses[0];
       fallbackStatusId = presentStatus.id;
    }

    let sId = parseInt(statusid, 10);
    if (isNaN(sId) || sId === 0) {
       sId = fallbackStatusId;
    }

    let acronym = 'P';
    const stat = validStatuses.find(s => s.id === sId);
    if (stat && stat.acronym) {
      acronym = stat.acronym;
    }

    const params = {
      sessionid: sessionid,
      studentid: studentid,
      takenbyid: studentid,  // El alumno se toma lista a sí mismo
      statusid: sId,
      statusset: acronym
    };

    const result = await callMoodle(
      'mod_attendance_update_user_status', // Función en singular
      params,
      MOODLE_ATTENDANCE_TOKEN, // Llave maestra
      'POST'
    );

    if (result?.exception) {
      return res.status(500).json({
        error: 'Moodle rechazó el auto-registro',
        detail: result,
      });
    }

    res.json({ ok: true, message: 'Auto-registro exitoso' });
  } catch (error) {
    res.status(500).json({
      error: 'Error al auto-registrar la asistencia',
      detail: error.message,
    });
  }
});


// --- RUTA VIEJA: ACTUALIZAR CONFIGURACIÓN DEL CURSO EN MOODLE (La dejamos intacta por seguridad) ---
app.post('/course-update-settings', async (req, res) => {
  try {
    const { token, courseid, cohortText, code, modality, loadHours, description } = req.body ?? {};

    if (!token || !courseid) {
      return res.status(400).json({ error: 'Faltan datos obligatorios (token, courseid)' });
    }

    const params = {
      'courses[0][id]': courseid,
      'courses[0][shortname]': cohortText,
      'courses[0][summary]': description,
    };

    let customFieldIndex = 0;

    if (code) {
      params[`courses[0][customfields][${customFieldIndex}][shortname]`] = 'codigo';
      params[`courses[0][customfields][${customFieldIndex}][value]`] = code;
      customFieldIndex++;
    }

    if (modality) {
      params[`courses[0][customfields][${customFieldIndex}][shortname]`] = 'modalidad';
      params[`courses[0][customfields][${customFieldIndex}][value]`] = modality;
      customFieldIndex++;
    }

    if (loadHours) {
      params[`courses[0][customfields][${customFieldIndex}][shortname]`] = 'carga';
      params[`courses[0][customfields][${customFieldIndex}][value]`] = loadHours;
    }

    const result = await callMoodle(
      'core_course_update_courses',
      params,
      token,
      'POST'
    );

    if (result?.exception) {
      return res.status(500).json({
        error: 'No se pudo actualizar el curso en Moodle',
        detail: result,
      });
    }

    res.json({ ok: true, message: 'Curso actualizado correctamente en Moodle' });

  } catch (error) {
    res.status(500).json({
      error: 'Error al actualizar el curso',
      detail: error.message,
    });
  }
});


// --- RUTA NUEVA: CREAR AVISO (FORO) ---
app.post('/teacher/create-notice', async (req, res) => {
  try {
    const { token, courseid, title, message, type, notify, pin } = req.body ?? {};

    if (!token || !courseid || !title || !message) {
      return res.status(400).json({ error: 'Faltan datos obligatorios' });
    }

    // 1. Buscar el foro de avisos del curso
    const contents = await callMoodle('core_course_get_contents', { courseid }, token);

    if (contents.exception) {
      return res.status(500).json({ error: 'Error al leer el curso', detail: contents });
    }

    let forumId = null;
    if (Array.isArray(contents)) {
      for (const section of contents) {
        if (section.modules && Array.isArray(section.modules)) {
          const forumModule = section.modules.find(mod => {
            if (mod.modname === 'forum') {
              const modName = (mod.name || '').toLowerCase();
              return modName.includes('aviso') || modName.includes('novedad') || modName.includes('anuncio');
            }
            return false;
          });
          if (forumModule) {
            forumId = forumModule.instance;
            break;
          }
        }
      }
    }

    if (!forumId) {
      return res.status(404).json({ error: 'No se encontró un foro de Avisos en este curso' });
    }

    // 2. Publicar el mensaje en el foro
    // Le agregamos el tipo al título para que se note visualmente en Moodle
    const finalSubject = `[${type}] ${title}`;

    const params = {
      forumid: forumId,
      subject: finalSubject,
      message: message,
    };

    if (pin) {
       params['options[0][name]'] = 'pinned';
       params['options[0][value]'] = 1; // 1 significa true en Moodle WS
    }

    const result = await callMoodle(
      'mod_forum_add_discussion',
      params,
      token,
      'POST'
    );

    if (result?.exception) {
      return res.status(500).json({
        error: 'No se pudo publicar el aviso en Moodle',
        detail: result,
      });
    }

    res.json({ ok: true, message: 'Aviso publicado correctamente', discussionid: result.discussionid });

  } catch (error) {
    res.status(500).json({
      error: 'Error al publicar el aviso',
      detail: error.message,
    });
  }
});

// --- RUTA NUEVA: ALUMNOS CREAN UN NUEVO DEBATE (TIPO TAREA) ---
app.post('/student/forum-new-discussion', async (req, res) => {
  try {
    const { token, forumid, subject, message } = req.body ?? {};
    if (!token || !forumid || !subject || !message) {
      return res.status(400).json({ error: 'Faltan datos obligatorios' });
    }
    const params = { forumid, subject, message };
    const result = await callMoodle('mod_forum_add_discussion', params, token, 'POST');

    if (result?.exception) {
      return res.status(500).json({ error: 'Moodle rechazó el debate', detail: result });
    }
    res.json({ ok: true, message: 'Debate publicado', discussionid: result.discussionid });
  } catch (error) {
    res.status(500).json({ error: 'Error interno al enviar', detail: error.message });
  }
});

// --- RUTA NUEVA: ALUMNOS Y DOCENTES RESPONDEN A UN DEBATE/AVISO ---
app.post('/student/forum-reply', async (req, res) => {
  try {
    const { token, discussionid, subject, message } = req.body ?? {};

    if (!token || !discussionid || !message) {
      return res.status(400).json({ error: 'Faltan datos obligatorios' });
    }

    // 1. Magia ninja: Buscamos el ID exacto del mensaje al que queremos responder
    const postsData = await callMoodle('mod_forum_get_forum_discussion_posts', { discussionid }, token);

    if (postsData.exception || !postsData.posts || postsData.posts.length === 0) {
       return res.status(400).json({ error: 'No se pudo encontrar el mensaje original en Moodle' });
    }

    const rootPostId = postsData.posts[0].id; // Agarramos el primer mensaje del hilo

    // 2. Mandamos la respuesta a Moodle
    const params = {
      postid: rootPostId,
      subject: subject || 'Respuesta',
      message: message,
    };

    const result = await callMoodle('mod_forum_add_discussion_post', params, token, 'POST');

    if (result?.exception) {
      return res.status(500).json({
        error: 'Moodle rechazó la respuesta (Quizás los alumnos no tienen permiso en este foro)',
        detail: result,
      });
    }

    res.json({ ok: true, message: 'Respuesta publicada correctamente', postid: result.postid });

  } catch (error) {
    res.status(500).json({ error: 'Error al enviar la respuesta', detail: error.message });
  }
});

// --- RUTA NUEVA: FORZAR INFO DE UN FORO ESPECÍFICO ---
app.get('/forum-info', async (req, res) => {
  try {
    const token = req.query.token?.toString() || MOODLE_TOKEN;
    const courseid = req.query.courseid?.toString();
    const forumid = req.query.forumid?.toString();

    if (!courseid || !forumid) {
      return res.status(400).json({ error: 'Falta courseid o forumid' });
    }

    const result = await callMoodle('mod_forum_get_forums_by_courses', { 'courseids[0]': courseid }, token);
    const forums = result || [];
    const myForum = forums.find(f => f.id == forumid);

    res.json(myForum || {});
  } catch (error) {
    res.status(500).json({ error: 'Error al consultar info del foro', detail: error.message });
  }
});

// --- RUTA NUEVA: CALENDARIO MENSUAL SÚPER RÁPIDO ---
app.get('/calendar-events', async (req, res) => {
  try {
    const token = req.query.token?.toString() || MOODLE_TOKEN;
    const year = req.query.year || new Date().getFullYear();
    const month = req.query.month || (new Date().getMonth() + 1);

    // Esta función es rapidísima porque solo descarga el mes exacto que le pedimos
    const result = await callMoodle('core_calendar_get_calendar_monthly_view', {
      year: year,
      month: month
    }, token);

    if (result.exception) {
      return res.status(500).json({ error: 'Error de Moodle', detail: result });
    }

    // Moodle devuelve un objeto gigante con semanas y días. Acá extraemos los eventos limpios.
    let allEvents = [];
    if (result.weeks) {
       result.weeks.forEach(week => {
         if (week.days) {
             week.days.forEach(day => {
                if (day.events && day.events.length > 0) {
                   allEvents.push(...day.events);
                }
             });
         }
       });
    }

    // ==============================================================================
    // ¡SUPERPODER NINJA! Inyectamos el estado "isCompleted" a cada evento
    // ==============================================================================
    const siteInfo = await callMoodle('core_webservice_get_site_info', {}, token);
    const userId = siteInfo.userid;

    const enhancedEvents = await Promise.all(allEvents.map(async (event) => {
        let isCompleted = false;

        try {
            const modName = (event.modulename || '').toLowerCase();
            const eventName = (event.name || '').toLowerCase();
            const courseId = event.course?.id || event.courseid;

            // 1. TAREAS (Assignments)
            if (modName === 'assign' || eventName.includes('tarea') || eventName.includes('trabajo') || eventName.includes('assign')) {
                let trueAssignId = null;

                // Siempre descargamos la lista de tareas del curso para asegurar el ID real
                if (courseId) {
                    const assignsData = await callMoodle('mod_assign_get_assignments', { 'courseids[0]': courseId }, token);
                    if (assignsData && assignsData.courses && assignsData.courses.length > 0) {
                        const tasks = assignsData.courses[0].assignments || [];
                        // Buscamos cruzando el instance con el id real o el cmid
                        let matched = tasks.find(t => t.id == event.instance || t.cmid == event.instance);

                        // Si los IDs no coinciden, buscamos por nombre (para eventos creados a mano)
                        if (!matched) {
                            matched = tasks.find(t => eventName.includes(t.name.toLowerCase()) || t.name.toLowerCase().includes(eventName));
                        }

                        if (matched) {
                            trueAssignId = matched.id;
                        }
                    }
                }

                if (trueAssignId) {
                    // ¡CORRECCIÓN CLAVE! Usamos el token del ALUMNO (token), el ID verificado, y NO enviamos userid.
                    const statusData = await callMoodle('mod_assign_get_submission_status', { assignid: trueAssignId }, token);

                    if (statusData && !statusData.exception) {
                        const subStatus = statusData.submissionstatus ||
                                         (statusData.lastattempt && statusData.lastattempt.submission ? statusData.lastattempt.submission.status : '');
                        if (subStatus === 'submitted' || subStatus === 'graded') {
                            isCompleted = true;
                        }
                    }
                }
            }
            // 2. ASISTENCIAS
            else if (modName === 'attendance' || eventName.includes('asistencia') || eventName.includes('presentismo')) {
                if (event.action && event.action.actionable === false) {
                    isCompleted = true;
                } else if (courseId) {
                    // EL TRUCO DE LA BARREDORA: Traemos TODOS los estados de asistencia del alumno en ese curso de una sola vez
                    // Reutilizamos el motor que sabemos que sí funciona en la pantalla de "Mi Asistencia"
                    const miAsistenciaData = await callMoodle(
                      'gradereport_user_get_grade_items',
                      { courseid: courseId, userid: userId },
                      token
                    );

                    if (miAsistenciaData.usergrades && miAsistenciaData.usergrades.length > 0) {
                        const gradeItems = miAsistenciaData.usergrades[0].gradeitems || [];
                        const filaAsistencia = gradeItems.find(item => item.itemmodule === 'attendance');

                        if (filaAsistencia) {
                            // Si el alumno tiene alguna nota oficial en asistencia, la marcamos como "revisada" o completa
                            const raw = filaAsistencia.graderaw;
                            const gradeFmt = (filaAsistencia.gradeformatted || '-').toString().trim();
                            const percFmt = (filaAsistencia.percentageformatted || '-').toString().trim();

                            const tieneNotaOficial = raw !== null ||
                                (gradeFmt !== '-' && gradeFmt !== '' && gradeFmt !== 'null') ||
                                (percFmt !== '-' && percFmt !== '' && percFmt !== 'null');

                            if (tieneNotaOficial) {
                                isCompleted = true;
                            }
                        }
                    }

                    // Si el boletín oficial falló, usamos nuestro motor interno para revisar sesión por sesión
                    if (!isCompleted) {
                         let attendanceId = null;
                         const contents = await callMoodle('core_course_get_contents', { courseid: courseId }, token);
                         if (Array.isArray(contents)) {
                             for (const section of contents) {
                                 if (section.modules && Array.isArray(section.modules)) {
                                     const attMod = section.modules.find(m => m.modname === 'attendance');
                                     if (attMod) {
                                         attendanceId = attMod.instance;
                                         break;
                                     }
                                 }
                             }
                         }

                         if (attendanceId) {
                             const sessionsData = await callMoodle('mod_attendance_get_sessions', { attendanceid: attendanceId }, MOODLE_ATTENDANCE_TOKEN);
                             if (Array.isArray(sessionsData)) {
                                 // Buscamos la sesión correspondiente a la fecha del evento (+/- 24 horas de margen)
                                 let matchingSession = null;
                                 sessionsData.forEach(s => {
                                     if (Math.abs(s.sessdate - event.timestart) < 86400) {
                                         matchingSession = s;
                                     }
                                 });

                                 if (matchingSession) {
                                     const detail = await callMoodle('mod_attendance_get_session', { sessionid: matchingSession.id }, MOODLE_ATTENDANCE_TOKEN);

                                     let myLog = null;
                                     if (detail && detail.attendance_log && Array.isArray(detail.attendance_log)) {
                                         myLog = detail.attendance_log.find(log => log.studentid == userId);
                                     }
                                     if (!myLog && detail && detail.users && Array.isArray(detail.users)) {
                                         const me = detail.users.find(u => u.id == userId);
                                         if (me && me.attendance_log) {
                                            myLog = Array.isArray(me.attendance_log) ? me.attendance_log[0] : me.attendance_log;
                                         }
                                     }

                                     if (myLog) {
                                         // Encontramos el log, el alumno estuvo presente/ausente, ¡ya se registró!
                                         isCompleted = true;
                                     }
                                 }
                             }
                         }
                    }
                }
            }
            // 3. OTRAS ACTIVIDADES CON "ACTION"
            else if (event.action && event.action.actionable === false) {
                 isCompleted = true;
            }

        } catch (err) {
            console.error('Error verificando evento', event.name, err.message);
        }

        return {
            ...event,
            isCompleted: isCompleted
        };
    }));

    // ==============================================================================

    res.json(enhancedEvents);
  } catch (error) {
    res.status(500).json({
      error: 'Error al consultar el calendario',
      detail: error.message,
    });
  }
});

// --- RUTA NUEVA: ACTUALIZAR FOTO DE PERFIL ---
app.post('/update-profile-picture', async (req, res) => {
  try {
    const { token, userid, fileName, fileBase64, mimeType } = req.body ?? {};

    if (!token || !userid || !fileName || !fileBase64) {
      return res.status(400).json({
        error: 'Faltan datos obligatorios para actualizar la foto',
      });
    }

    // 1. Pedirle a Moodle un espacio temporal (draft area) para subir la foto
    let draftItemId = await callMoodle(
      'core_files_get_unused_draft_itemid',
      {},
      token,
    );

    // ¡ACÁ ESTÁ LA OTRA CORRECCIÓN PARA LA FOTO DE PERFIL!
    if (typeof draftItemId === 'object' && draftItemId !== null && draftItemId.itemid) {
      draftItemId = draftItemId.itemid;
    }

    if (!draftItemId || typeof draftItemId !== 'number') {
      return res.status(500).json({
        error: 'No se pudo obtener área temporal de Moodle',
        detail: draftItemId,
      });
    }

    // Limpiamos el base64 por si viene con encabezados extras de Flutter
    const cleanBase64 = fileBase64.includes(',')
      ? fileBase64.split(',').pop()
      : fileBase64;

    const fileBuffer = Buffer.from(cleanBase64, 'base64');

    // 2. Subimos la foto al área temporal
    const uploadResult = await uploadFileToDraft({
      token,
      draftItemId,
      fileName,
      mimeType,
      fileBuffer,
    });

    if (!Array.isArray(uploadResult) || uploadResult.length === 0 || uploadResult[0]?.error) {
      return res.status(500).json({
        error: 'Moodle rechazó la subida de la foto',
        detail: uploadResult,
      });
    }

    // 3. Le decimos a Moodle que actualice el perfil usando el archivo que acabamos de subir
    const updateResult = await callMoodle(
      'core_user_update_picture',
      {
        draftitemid: draftItemId,
        userid: userid,
      },
      token,
      'POST'
    );

    if (updateResult?.exception) {
      return res.status(500).json({
        error: 'No se pudo actualizar la foto de perfil en Moodle',
        detail: updateResult,
      });
    }

    res.json({
      ok: true,
      message: 'Foto de perfil actualizada correctamente',
      success: updateResult.success,
    });
  } catch (error) {
    res.status(500).json({
      error: 'Error al actualizar la foto de perfil',
      detail: error.message,
    });
  }
});

// =========================================================================
// --- ¡LAS NUEVAS RUTAS DE LA MINI-BASE DE DATOS PARA LOS CURSOS! ---
// =========================================================================

const settingsFilePath = path.join(__dirname, 'configuraciones_cursos.json');

// Función que lee (o crea si no existe) el archivo JSON
function leerConfiguraciones() {
  if (!fs.existsSync(settingsFilePath)) {
    fs.writeFileSync(settingsFilePath, JSON.stringify({}));
  }
  const data = fs.readFileSync(settingsFilePath, 'utf8');
  return JSON.parse(data);
}

// RUTA PARA GUARDAR LA CONFIGURACIÓN (Flutter la llamará al tocar "Guardar")
app.post('/guardar-config-curso', (req, res) => {
  const { courseId, codigo, cohorte, modalidad, cargaHoraria } = req.body;

  if (!courseId) {
    return res.status(400).json({ error: 'Falta el ID del curso' });
  }

  try {
    const configuraciones = leerConfiguraciones();

    // Guardamos la info. Si ya existía info vieja, la sobrescribimos con la nueva.
    configuraciones[courseId] = {
      ...(configuraciones[courseId] || {}),
      codigo: codigo || '',
      cohorte: cohorte || '',
      modalidad: modalidad || '',
      cargaHoraria: cargaHoraria || ''
    };

    // Escribimos los cambios en el archivo JSON físico
    fs.writeFileSync(settingsFilePath, JSON.stringify(configuraciones, null, 2));

    res.json({ success: true, message: '¡Datos guardados exitosamente en la mini base!' });
  } catch (error) {
    console.error('Error al guardar configuración local:', error);
    res.status(500).json({ error: 'Error interno del servidor al guardar' });
  }
});

// RUTA PARA OBTENER LA CONFIGURACIÓN (Flutter la llamará al abrir la pantalla)
app.get('/obtener-config-curso/:courseId', (req, res) => {
  const { courseId } = req.params;

  try {
    const configuraciones = leerConfiguraciones();
    const configCurso = configuraciones[courseId];

    if (configCurso) {
      res.json(configCurso);
    } else {
      // Devolvemos las variables vacías con los nombres correctos
      res.json({
        cohortText: '', code: '', modality: '', loadHours: '', description: ''
      });
    }
  } catch (error) {
    console.error('Error al leer configuración local:', error);
    res.status(500).json({ error: 'Error interno del servidor al leer' });
  }
});

// =========================================================================
// --- RUTA NUEVA: GENERAR LINK MÁGICO PARA ABRIR EXÁMENES EN WEB ---
// =========================================================================
app.post('/get-autologin-url', async (req, res) => {
  try {
    const { token, privatetoken, destinationUrl } = req.body ?? {};

    if (!token || !privatetoken || !destinationUrl) {
      return res.status(400).json({ error: 'Faltan token, privatetoken o destinationUrl' });
    }

    console.log('🔑 Intentando autologin para URL:', destinationUrl);
    console.log('🤫 PrivateToken enviado:', privatetoken);

    // 1. Le pedimos a Moodle la llave de acceso rápido
    const result = await callMoodle(
      'tool_mobile_get_autologin_key',
      { privatetoken: privatetoken },
      token,
      'POST'
    );

    console.log('🛑 RESPUESTA DE MOODLE:', result); // <--- ¡NUESTRO ESPÍA!

    if (result.exception || !result.autologinurl) {
      return res.status(500).json({ error: 'Moodle rechazó el autologin', detail: result });
    }

    // 2. Armamos el Link Mágico de un solo uso
    const magicUrl = `${result.autologinurl}?userid=${result.userid}&key=${result.key}&urlto=${encodeURIComponent(destinationUrl)}`;

    console.log('✅ Link mágico generado con éxito');
    res.json({ ok: true, magicUrl: magicUrl });

  } catch (error) {
    console.error('🔥 Error interno en autologin:', error);
    res.status(500).json({
      error: 'Error interno al generar autologin',
      detail: error.message,
    });
  }
});

app.listen(PORT, () => {
  console.log(`Servidor corriendo en http://localhost:${PORT}`);
});