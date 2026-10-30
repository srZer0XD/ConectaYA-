-- Necesaria para generar UUID
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Necesaria para las restricciones de rangos de tiempo
CREATE EXTENSION IF NOT EXISTS btree_gist;


CREATE TABLE usuarios (
    id_usuario BIGSERIAL PRIMARY KEY,

    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,

    email VARCHAR(150) NOT NULL UNIQUE,

    telefono VARCHAR(20),

    password_hash TEXT NOT NULL,

    rol VARCHAR(20) NOT NULL DEFAULT 'cliente',

    estado VARCHAR(20) NOT NULL DEFAULT 'activo',

    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    fecha_actualizacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_usuario_rol
        CHECK (rol IN ('cliente', 'profesional', 'administrador')),

    CONSTRAINT chk_usuario_estado
        CHECK (estado IN ('activo', 'bloqueado', 'inactivo')),

    CONSTRAINT chk_usuario_email
        CHECK (email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'),

    CONSTRAINT chk_usuario_nombre
        CHECK (length(trim(nombre)) >= 2),

    CONSTRAINT chk_usuario_apellido
        CHECK (length(trim(apellido)) >= 2)
);


CREATE TABLE recuperacion_password (
    id_recuperacion BIGSERIAL PRIMARY KEY,

    id_usuario BIGINT NOT NULL,

    token UUID NOT NULL DEFAULT gen_random_uuid(),

    fecha_solicitud TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    fecha_expiracion TIMESTAMPTZ NOT NULL,

    usado BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT fk_recuperacion_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES usuarios(id_usuario)
        ON DELETE CASCADE,

    CONSTRAINT uq_recuperacion_token
        UNIQUE (token),

    CONSTRAINT chk_fecha_expiracion
        CHECK (fecha_expiracion > fecha_solicitud)
);


CREATE TABLE profesionales (
    id_profesional BIGSERIAL PRIMARY KEY,

    id_usuario BIGINT NOT NULL UNIQUE,

    descripcion TEXT,

    experiencia_anios INTEGER DEFAULT 0,

    fecha_inicio_profesion DATE,

    calificacion_promedio NUMERIC(3,2) NOT NULL DEFAULT 0.00,

    cantidad_calificaciones INTEGER NOT NULL DEFAULT 0,

    estado VARCHAR(20) NOT NULL DEFAULT 'activo',

    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    fecha_actualizacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_profesional_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES usuarios(id_usuario)
        ON DELETE CASCADE,

    CONSTRAINT chk_experiencia
        CHECK (experiencia_anios >= 0),

    CONSTRAINT chk_calificacion
        CHECK (
            calificacion_promedio >= 0
            AND calificacion_promedio <= 5
        ),

    CONSTRAINT chk_cantidad_calificaciones
        CHECK (cantidad_calificaciones >= 0),

    CONSTRAINT chk_estado_profesional
        CHECK (estado IN ('activo', 'inactivo', 'pendiente'))
);

CREATE TABLE ubicaciones_profesional (
    id_ubicacion BIGSERIAL PRIMARY KEY,

    id_profesional BIGINT NOT NULL UNIQUE,

    direccion VARCHAR(250) NOT NULL,

    distrito VARCHAR(100) NOT NULL,

    provincia VARCHAR(100) NOT NULL,

    departamento VARCHAR(100) NOT NULL,

    latitud NUMERIC(9,6),

    longitud NUMERIC(9,6),

    fecha_actualizacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_ubicacion_profesional
        FOREIGN KEY (id_profesional)
        REFERENCES profesionales(id_profesional)
        ON DELETE CASCADE,

    CONSTRAINT chk_latitud
        CHECK (latitud IS NULL OR latitud BETWEEN -90 AND 90),

    CONSTRAINT chk_longitud
        CHECK (longitud IS NULL OR longitud BETWEEN -180 AND 180)
);


CREATE TABLE documentos_profesional (
    id_documento BIGSERIAL PRIMARY KEY,

    id_profesional BIGINT NOT NULL,

    tipo_documento VARCHAR(30) NOT NULL,

    numero_documento VARCHAR(30) NOT NULL,

    ruta_archivo TEXT,

    estado_validacion VARCHAR(20) NOT NULL DEFAULT 'pendiente',

    fecha_subida TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    fecha_validacion TIMESTAMPTZ,

    CONSTRAINT fk_documento_profesional
        FOREIGN KEY (id_profesional)
        REFERENCES profesionales(id_profesional)
        ON DELETE CASCADE,

    CONSTRAINT chk_tipo_documento
        CHECK (
            tipo_documento IN (
                'DNI',
                'RUC',
                'CERTIFICADO',
                'OTRO'
            )
        ),

    CONSTRAINT chk_estado_validacion
        CHECK (
            estado_validacion IN (
                'pendiente',
                'aprobado',
                'rechazado'
            )
        ),

    CONSTRAINT uq_documento
        UNIQUE (tipo_documento, numero_documento)
);

CREATE TABLE contactos_profesional (
    id_contacto BIGSERIAL PRIMARY KEY,

    id_profesional BIGINT NOT NULL,

    tipo_contacto VARCHAR(30) NOT NULL,

    valor VARCHAR(150) NOT NULL,

    es_principal BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT fk_contacto_profesional
        FOREIGN KEY (id_profesional)
        REFERENCES profesionales(id_profesional)
        ON DELETE CASCADE,

    CONSTRAINT chk_tipo_contacto
        CHECK (
            tipo_contacto IN (
                'telefono',
                'whatsapp',
                'email',
                'red_social'
            )
        )
);


CREATE TABLE categorias_servicio (
    id_categoria BIGSERIAL PRIMARY KEY,

    nombre VARCHAR(100) NOT NULL UNIQUE,

    descripcion TEXT,

    estado BOOLEAN NOT NULL DEFAULT TRUE
);


CREATE TABLE servicios (
    id_servicio BIGSERIAL PRIMARY KEY,

    id_profesional BIGINT NOT NULL,

    id_categoria BIGINT NOT NULL,

    nombre VARCHAR(150) NOT NULL,

    descripcion TEXT NOT NULL,

    precio NUMERIC(10,2) NOT NULL,

    duracion_minutos INTEGER NOT NULL,

    estado VARCHAR(20) NOT NULL DEFAULT 'activo',

    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    fecha_actualizacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_servicio_profesional
        FOREIGN KEY (id_profesional)
        REFERENCES profesionales(id_profesional)
        ON DELETE CASCADE,

    CONSTRAINT fk_servicio_categoria
        FOREIGN KEY (id_categoria)
        REFERENCES categorias_servicio(id_categoria),

    CONSTRAINT chk_precio
        CHECK (precio >= 0),

    CONSTRAINT chk_duracion
        CHECK (duracion_minutos > 0),

    CONSTRAINT chk_estado_servicio
        CHECK (
            estado IN (
                'activo',
                'inactivo'
            )
        ),

    CONSTRAINT uq_servicio_profesional_nombre
        UNIQUE (id_profesional, nombre)
);


CREATE TABLE disponibilidad_profesional (
    id_disponibilidad BIGSERIAL PRIMARY KEY,

    id_profesional BIGINT NOT NULL,

    dia_semana INTEGER NOT NULL,

    hora_inicio TIME NOT NULL,

    hora_fin TIME NOT NULL,

    estado BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT fk_disponibilidad_profesional
        FOREIGN KEY (id_profesional)
        REFERENCES profesionales(id_profesional)
        ON DELETE CASCADE,

    CONSTRAINT chk_dia_semana
        CHECK (dia_semana BETWEEN 1 AND 7),

    CONSTRAINT chk_horas
        CHECK (hora_fin > hora_inicio),

    CONSTRAINT uq_disponibilidad
        UNIQUE (
            id_profesional,
            dia_semana,
            hora_inicio,
            hora_fin
        )
);


CREATE TABLE reservas (
    id_reserva BIGSERIAL PRIMARY KEY,

    id_cliente BIGINT NOT NULL,

    id_profesional BIGINT NOT NULL,

    id_servicio BIGINT NOT NULL,

    fecha_hora_inicio TIMESTAMPTZ NOT NULL,

    fecha_hora_fin TIMESTAMPTZ NOT NULL,

    estado VARCHAR(20) NOT NULL DEFAULT 'pendiente',

    mensaje_cliente TEXT,

    motivo_cancelacion TEXT,

    fecha_solicitud TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    fecha_respuesta TIMESTAMPTZ,

    fecha_cancelacion TIMESTAMPTZ,

    CONSTRAINT fk_reserva_cliente
        FOREIGN KEY (id_cliente)
        REFERENCES usuarios(id_usuario),

    CONSTRAINT fk_reserva_profesional
        FOREIGN KEY (id_profesional)
        REFERENCES profesionales(id_profesional),

    CONSTRAINT fk_reserva_servicio
        FOREIGN KEY (id_servicio)
        REFERENCES servicios(id_servicio),

    CONSTRAINT chk_fecha_reserva
        CHECK (fecha_hora_fin > fecha_hora_inicio),

    CONSTRAINT chk_estado_reserva
        CHECK (
            estado IN (
                'pendiente',
                'aceptada',
                'rechazada',
                'cancelada',
                'completada'
            )
        )
);


ALTER TABLE reservas
ADD CONSTRAINT no_reservas_superpuestas
EXCLUDE USING gist (
    id_profesional WITH =,
    tstzrange(
        fecha_hora_inicio,
        fecha_hora_fin,
        '[)'
    ) WITH &&
)
WHERE (
    estado IN ('pendiente', 'aceptada')
);


CREATE TABLE calificaciones (
    id_calificacion BIGSERIAL PRIMARY KEY,

    id_reserva BIGINT NOT NULL UNIQUE,

    id_cliente BIGINT NOT NULL,

    id_profesional BIGINT NOT NULL,

    puntuacion INTEGER NOT NULL,

    comentario TEXT,

    fecha_calificacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_calificacion_reserva
        FOREIGN KEY (id_reserva)
        REFERENCES reservas(id_reserva)
        ON DELETE RESTRICT,

    CONSTRAINT fk_calificacion_cliente
        FOREIGN KEY (id_cliente)
        REFERENCES usuarios(id_usuario),

    CONSTRAINT fk_calificacion_profesional
        FOREIGN KEY (id_profesional)
        REFERENCES profesionales(id_profesional),

    CONSTRAINT chk_puntuacion
        CHECK (puntuacion BETWEEN 1 AND 5)
);


CREATE TABLE conversaciones (
    id_conversacion BIGSERIAL PRIMARY KEY,

    id_cliente BIGINT NOT NULL,

    id_profesional BIGINT NOT NULL,

    id_servicio BIGINT,

    fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    estado VARCHAR(20) NOT NULL DEFAULT 'activa',

    CONSTRAINT fk_conversacion_cliente
        FOREIGN KEY (id_cliente)
        REFERENCES usuarios(id_usuario),

    CONSTRAINT fk_conversacion_profesional
        FOREIGN KEY (id_profesional)
        REFERENCES profesionales(id_profesional),

    CONSTRAINT fk_conversacion_servicio
        FOREIGN KEY (id_servicio)
        REFERENCES servicios(id_servicio),

    CONSTRAINT chk_estado_conversacion
        CHECK (
            estado IN ('activa', 'cerrada')
        )
);


CREATE TABLE mensajes (
    id_mensaje BIGSERIAL PRIMARY KEY,

    id_conversacion BIGINT NOT NULL,

    id_remitente BIGINT NOT NULL,

    contenido TEXT NOT NULL,

    fecha_envio TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    leido BOOLEAN NOT NULL DEFAULT FALSE,

    fecha_lectura TIMESTAMPTZ,

    CONSTRAINT fk_mensaje_conversacion
        FOREIGN KEY (id_conversacion)
        REFERENCES conversaciones(id_conversacion)
        ON DELETE CASCADE,

    CONSTRAINT fk_mensaje_remitente
        FOREIGN KEY (id_remitente)
        REFERENCES usuarios(id_usuario),

    CONSTRAINT chk_contenido
        CHECK (length(trim(contenido)) > 0),

    CONSTRAINT chk_fecha_lectura
        CHECK (
            fecha_lectura IS NULL
            OR fecha_lectura >= fecha_envio
        )
);


CREATE INDEX idx_usuarios_email
ON usuarios(email);

CREATE INDEX idx_profesionales_usuario
ON profesionales(id_usuario);

CREATE INDEX idx_servicios_profesional
ON servicios(id_profesional);

CREATE INDEX idx_servicios_categoria
ON servicios(id_categoria);

CREATE INDEX idx_servicios_precio
ON servicios(precio);

CREATE INDEX idx_servicios_estado
ON servicios(estado);

CREATE INDEX idx_profesionales_calificacion
ON profesionales(calificacion_promedio DESC);

CREATE INDEX idx_profesionales_fecha
ON profesionales(fecha_registro);

CREATE INDEX idx_ubicacion_distrito
ON ubicaciones_profesional(distrito);

CREATE INDEX idx_ubicacion_provincia
ON ubicaciones_profesional(provincia);

CREATE INDEX idx_reservas_cliente
ON reservas(id_cliente);

CREATE INDEX idx_reservas_profesional
ON reservas(id_profesional);

CREATE INDEX idx_reservas_estado
ON reservas(estado);

CREATE INDEX idx_reservas_fecha
ON reservas(fecha_hora_inicio);

CREATE INDEX idx_mensajes_conversacion
ON mensajes(id_conversacion, fecha_envio);

CREATE INDEX idx_mensajes_remitente
ON mensajes(id_remitente);


CREATE OR REPLACE FUNCTION actualizar_fecha_modificacion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.fecha_actualizacion = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


CREATE TRIGGER trg_usuarios_actualizacion
BEFORE UPDATE ON usuarios
FOR EACH ROW
EXECUTE FUNCTION actualizar_fecha_modificacion();


CREATE TRIGGER trg_profesionales_actualizacion
BEFORE UPDATE ON profesionales
FOR EACH ROW
EXECUTE FUNCTION actualizar_fecha_modificacion();


CREATE TRIGGER trg_servicios_actualizacion
BEFORE UPDATE ON servicios
FOR EACH ROW
EXECUTE FUNCTION actualizar_fecha_modificacion();

CREATE OR REPLACE FUNCTION actualizar_calificacion_profesional()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    UPDATE profesionales
    SET
        calificacion_promedio = (
            SELECT COALESCE(AVG(puntuacion), 0)
            FROM calificaciones
            WHERE id_profesional = NEW.id_profesional
        ),

        cantidad_calificaciones = (
            SELECT COUNT(*)
            FROM calificaciones
            WHERE id_profesional = NEW.id_profesional
        )

    WHERE id_profesional = NEW.id_profesional;

    RETURN NEW;

END;
$$;


CREATE TRIGGER trg_actualizar_calificacion
AFTER INSERT OR UPDATE ON calificaciones
FOR EACH ROW
EXECUTE FUNCTION actualizar_calificacion_profesional();


CREATE OR REPLACE FUNCTION validar_calificacion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    estado_reserva VARCHAR(20);
    cliente_reserva BIGINT;
    profesional_reserva BIGINT;
BEGIN

    SELECT
        estado,
        id_cliente,
        id_profesional
    INTO
        estado_reserva,
        cliente_reserva,
        profesional_reserva
    FROM reservas
    WHERE id_reserva = NEW.id_reserva;

    IF estado_reserva <> 'completada' THEN
        RAISE EXCEPTION
            'Solo se puede calificar una reserva completada';
    END IF;

    IF cliente_reserva <> NEW.id_cliente THEN
        RAISE EXCEPTION
            'El usuario no pertenece a esta reserva';
    END IF;

    IF profesional_reserva <> NEW.id_profesional THEN
        RAISE EXCEPTION
            'El profesional no pertenece a esta reserva';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_calificacion
BEFORE INSERT ON calificaciones
FOR EACH ROW
EXECUTE FUNCTION validar_calificacion();

CREATE OR REPLACE FUNCTION validar_servicio_reserva()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    profesional_servicio BIGINT;
BEGIN

    SELECT id_profesional
    INTO profesional_servicio
    FROM servicios
    WHERE id_servicio = NEW.id_servicio;

    IF profesional_servicio <> NEW.id_profesional THEN
        RAISE EXCEPTION
            'El servicio no pertenece al profesional seleccionado';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validar_servicio_reserva
BEFORE INSERT OR UPDATE ON reservas
FOR EACH ROW
EXECUTE FUNCTION validar_servicio_reserva();


CREATE OR REPLACE FUNCTION validar_cliente_profesional()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    usuario_profesional BIGINT;
BEGIN

    SELECT id_usuario
    INTO usuario_profesional
    FROM profesionales
    WHERE id_profesional = NEW.id_profesional;

    IF usuario_profesional = NEW.id_cliente THEN
        RAISE EXCEPTION
            'Un profesional no puede reservar su propio servicio';
    END IF;

    RETURN NEW;
END;
$$;


CREATE TRIGGER trg_validar_cliente_profesional
BEFORE INSERT OR UPDATE ON reservas
FOR EACH ROW
EXECUTE FUNCTION validar_cliente_profesional();

---Consultas

SELECT * FROM usuarios;

