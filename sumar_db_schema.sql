--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- Name: gral_adm_catalogos(text, text[]); Type: FUNCTION; Schema: public; Owner: sumar
--

CREATE FUNCTION gral_adm_catalogos(campos_data text, extra_data text[]) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    
    --estas  variables se utilizan en la mayoria de los catalogos
    str_data text[];

    app_selected integer;
    command_selected text;
    valor_retorno character varying;
    usuario_id integer;
    ultimo_id integer;

    str_filas text[];
        total_filas integer;--total de elementos de arreglo
    cont_fila integer;--contador de filas o posiciones del arreglo
    rowCount integer;

BEGIN
    --convertir cadena en arreglo
    SELECT INTO str_data string_to_array(''||campos_data||'','___');
    
    --aplicativo seleccionado
    app_selected := str_data[1]::integer;
    
    command_selected := str_data[2];--new, edit, delete. Para aplicativo 14 pagos: pago, anticipo, cancelacion
    
    -- usuario que utiliza el aplicativo
    usuario_id := str_data[3]::integer;



        valor_retorno:='0';
        
    --Empieza Job Actualiza Moneda
    IF app_selected = 121 THEN
        IF command_selected = 'new' THEN
            --str_data[4]        id
            --str_data[5]        valor
            --str_data[5]        tc
            --str_data[6]        moneda_desc
            
            total_filas:= array_length(extra_data,1);--obtiene total de elementos del arreglo
            cont_fila:=1;
            
            IF extra_data[1]<>'sin datos' THEN
                FOR cont_fila IN 1 .. total_filas LOOP
                    SELECT INTO str_filas string_to_array(extra_data[cont_fila],'___');

                    --RAISE EXCEPTION '%','extra_data[cont_fila]::'||extra_data[cont_fila];
                    
                    if str_filas[2]::double precision>0 then 
                        select id from gral_mon where descripcion ilike '%'||str_filas[1]||'%' and borrado_logico=false limit 1 INTO ultimo_id;

                        IF ultimo_id is not null THEN 
                            select count(id) as cantidad from erp_monedavers where moneda_id=ultimo_id and momento_creacion > (select (select now())::date) INTO rowCount;
                            
                            IF rowCount <= 0 THEN 
                                INSERT INTO erp_monedavers (moneda_id, valor, momento_creacion, version) 
                                VALUES (ultimo_id, str_filas[2]::double precision, now(), str_filas[3]);
                            end if;
                        end if;
                    end if;
                END LOOP;
            END IF;
            valor_retorno := '1';
        END IF;    
        
    END IF;--termina Job Actualiza Moneda
    
        
    RETURN valor_retorno;
    
END;$$;


ALTER FUNCTION public.gral_adm_catalogos(campos_data text, extra_data text[]) OWNER TO sumar;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: gral_rol; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE gral_rol (
    id integer NOT NULL,
    titulo character varying DEFAULT ''::character varying,
    authority character varying NOT NULL,
    borrado_logico boolean DEFAULT false,
    gral_app_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE gral_rol OWNER TO sumar;

--
-- Name: TABLE gral_rol; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON TABLE gral_rol IS 'Tabla que relaciona al usuario y el rol que este juega en el sistema';


--
-- Name: gral_usr; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE gral_usr (
    id integer NOT NULL,
    username character varying NOT NULL,
    password character varying NOT NULL,
    enabled boolean NOT NULL,
    ultimo_acceso timestamp with time zone,
    gral_empleados_id integer DEFAULT 0
);


ALTER TABLE gral_usr OWNER TO sumar;

--
-- Name: gral_usr_rol; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE gral_usr_rol (
    id integer NOT NULL,
    gral_usr_id integer NOT NULL,
    gral_rol_id integer NOT NULL
);


ALTER TABLE gral_usr_rol OWNER TO sumar;

--
-- Name: authorities; Type: VIEW; Schema: public; Owner: sumar
--

CREATE VIEW authorities AS
 SELECT gral_usr.username,
    gral_rol.authority
   FROM ((gral_usr
     JOIN gral_usr_rol ON ((gral_usr_rol.gral_usr_id = gral_usr.id)))
     JOIN gral_rol ON ((gral_rol.id = gral_usr_rol.gral_rol_id)))
  WHERE (gral_rol.borrado_logico = false);


ALTER TABLE authorities OWNER TO sumar;

--
-- Name: erp_monedavers; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE erp_monedavers (
    id integer NOT NULL,
    valor double precision NOT NULL,
    momento_creacion timestamp with time zone,
    moneda_id integer NOT NULL,
    version character varying NOT NULL
);


ALTER TABLE erp_monedavers OWNER TO sumar;

--
-- Name: erp_monedavers_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE erp_monedavers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE erp_monedavers_id_seq OWNER TO sumar;

--
-- Name: erp_monedavers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE erp_monedavers_id_seq OWNED BY erp_monedavers.id;


--
-- Name: gral_categ; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE gral_categ (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    sueldo_por_hora double precision NOT NULL,
    sueldo_por_horas_ext double precision NOT NULL,
    gral_puesto_id integer NOT NULL,
    borrado_logico boolean DEFAULT false NOT NULL,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0
);


ALTER TABLE gral_categ OWNER TO sumar;

--
-- Name: COLUMN gral_categ.id; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN gral_categ.id IS 'Llave primaria de Categorias';


--
-- Name: COLUMN gral_categ.titulo; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN gral_categ.titulo IS 'Nombre de la Categoria del Operario';


--
-- Name: COLUMN gral_categ.sueldo_por_hora; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN gral_categ.sueldo_por_hora IS 'Sueldo por Hora Normal';


--
-- Name: COLUMN gral_categ.sueldo_por_horas_ext; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN gral_categ.sueldo_por_horas_ext IS 'Sueldo por Hora de tiempo Extra';


--
-- Name: COLUMN gral_categ.gral_emp_id; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN gral_categ.gral_emp_id IS 'Empresa a la que pertenece la Categoria';


--
-- Name: COLUMN gral_categ.gral_suc_id; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN gral_categ.gral_suc_id IS 'Sucursal a la que pertenece';


--
-- Name: gral_categ_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_categ_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_categ_id_seq OWNER TO sumar;

--
-- Name: gral_categ_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_categ_id_seq OWNED BY gral_categ.id;


--
-- Name: gral_civils; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE gral_civils (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    borrado_logico boolean DEFAULT false NOT NULL
);


ALTER TABLE gral_civils OWNER TO sumar;

--
-- Name: gral_civils_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_civils_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_civils_id_seq OWNER TO sumar;

--
-- Name: gral_civils_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_civils_id_seq OWNED BY gral_civils.id;


--
-- Name: gral_deptos; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE gral_deptos (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    costo_prorrateo double precision,
    vigente boolean DEFAULT true NOT NULL,
    borrado_logico boolean DEFAULT false NOT NULL,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0
);


ALTER TABLE gral_deptos OWNER TO sumar;

--
-- Name: gral_deptos_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_deptos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_deptos_id_seq OWNER TO sumar;

--
-- Name: gral_deptos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_deptos_id_seq OWNED BY gral_deptos.id;


--
-- Name: gral_edo; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE gral_edo (
    id integer NOT NULL,
    titulo character varying,
    abreviacion character varying,
    pais_id integer NOT NULL
);


ALTER TABLE gral_edo OWNER TO sumar;

--
-- Name: TABLE gral_edo; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON TABLE gral_edo IS 'Estados que pueden ser seleccionados en los aplicativos del sistema, en funcion del pais seleccionado previamente en estos aplicativos';


--
-- Name: gral_edo_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_edo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_edo_id_seq OWNER TO sumar;

--
-- Name: gral_edo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_edo_id_seq OWNED BY gral_edo.id;


--
-- Name: gral_emails; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE gral_emails (
    id integer NOT NULL,
    gral_emp_id integer DEFAULT 0 NOT NULL,
    gral_suc_id integer DEFAULT 0 NOT NULL,
    email character varying DEFAULT ''::character varying,
    passwd character varying DEFAULT ''::character varying,
    borrado_logico boolean DEFAULT false NOT NULL,
    port character varying DEFAULT ''::character varying,
    host character varying DEFAULT ''::character varying
);


ALTER TABLE gral_emails OWNER TO sumar;

--
-- Name: gral_emails_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_emails_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_emails_id_seq OWNER TO sumar;

--
-- Name: gral_emails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_emails_id_seq OWNED BY gral_emails.id;


--
-- Name: gral_emp; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE gral_emp (
    id integer NOT NULL,
    titulo character varying(60),
    colonia character varying(60),
    cp character varying(6),
    calle character varying(60),
    rfc character varying(15),
    numero_interior character varying(10),
    numero_exterior character varying(10),
    momento_creacion timestamp with time zone NOT NULL,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    telefono character varying NOT NULL,
    borrado_logico boolean DEFAULT false NOT NULL,
    estado_id integer NOT NULL,
    municipio_id integer NOT NULL,
    pais_id integer NOT NULL,
    regimen_fiscal character varying NOT NULL,
    incluye_produccion boolean DEFAULT false NOT NULL,
    email_compras character varying DEFAULT ''::character varying,
    pass_email_compras character varying DEFAULT ''::character varying,
    pagina_web character varying DEFAULT ''::character varying,
    incluye_contabilidad boolean DEFAULT false NOT NULL,
    nivel_cta smallint DEFAULT 3 NOT NULL,
    incluye_crm boolean DEFAULT false NOT NULL,
    encluye_envasado boolean DEFAULT false NOT NULL,
    control_exis_pres boolean DEFAULT false NOT NULL,
    lista_precio_clientes boolean DEFAULT false NOT NULL,
    tipo_facturacion character varying DEFAULT ''::character varying NOT NULL,
    pac_facturacion integer DEFAULT 0 NOT NULL,
    ambiente_facturacion boolean DEFAULT false NOT NULL,
    gral_impto_id integer DEFAULT 1 NOT NULL,
    transportista boolean DEFAULT false NOT NULL,
    tasa_retencion double precision DEFAULT 0 NOT NULL,
    nomina boolean DEFAULT false NOT NULL,
    no_id integer DEFAULT 0 NOT NULL,
    incluye_log boolean DEFAULT false NOT NULL,
    gral_tc_url_id integer DEFAULT 0 NOT NULL,
    CONSTRAINT chk_ambiente_facturacion CHECK (((ambiente_facturacion = true) OR (ambiente_facturacion = false))),
    CONSTRAINT chk_lista_precio CHECK (((lista_precio_clientes = true) OR (lista_precio_clientes = false))),
    CONSTRAINT chk_pac CHECK ((pac_facturacion = ANY (ARRAY[0, 1, 2]))),
    CONSTRAINT chk_tipo_facturacion CHECK (((((tipo_facturacion)::text = 'cfd'::text) OR ((tipo_facturacion)::text = 'cfdi'::text)) OR ((tipo_facturacion)::text = 'cfditf'::text)))
);


ALTER TABLE gral_emp OWNER TO sumar;

--
-- Name: TABLE gral_emp; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON TABLE gral_emp IS 'Tabla que alberga las empresas que manejara el Sistema';


--
-- Name: COLUMN gral_emp.control_exis_pres; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN gral_emp.control_exis_pres IS 'TRUE=Controla existencias por Presentaciones, FALSE=No Controla existencias por Presentaciones ';


--
-- Name: COLUMN gral_emp.lista_precio_clientes; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN gral_emp.lista_precio_clientes IS 'TRUE=Es obligatorio asignar una Lista de Precio a todos los Clientes. FALSE=Permite dejar un Cliente sin Lista de Precio.';


--
-- Name: COLUMN gral_emp.tipo_facturacion; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN gral_emp.tipo_facturacion IS 'cfd, cfdi(Conector Fiscal), cfditf(Timbrado Fiscal)';


--
-- Name: COLUMN gral_emp.pac_facturacion; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN gral_emp.pac_facturacion IS '0=No hay Pac(CFD), 1=Diverza(CFDI, CFDITF), 2=SERVISIM(CFDITF)';


--
-- Name: COLUMN gral_emp.ambiente_facturacion; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN gral_emp.ambiente_facturacion IS 'Ambiente de Facturacion, TRUE=produccion, FALSE=prueba, solo aplica para Facturacion por Timbre Fiscal';


--
-- Name: COLUMN gral_emp.gral_impto_id; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN gral_emp.gral_impto_id IS 'IVA general';


--
-- Name: gral_emp_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_emp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_emp_id_seq OWNER TO sumar;

--
-- Name: gral_emp_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_emp_id_seq OWNED BY gral_emp.id;


--
-- Name: gral_emp_leyenda; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE gral_emp_leyenda (
    id integer NOT NULL,
    leyenda character varying NOT NULL,
    gral_emp_id integer NOT NULL
);


ALTER TABLE gral_emp_leyenda OWNER TO sumar;

--
-- Name: gral_emp_leyenda_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_emp_leyenda_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_emp_leyenda_id_seq OWNER TO sumar;

--
-- Name: gral_emp_leyenda_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_emp_leyenda_id_seq OWNED BY gral_emp_leyenda.id;


--
-- Name: gral_empleados; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE gral_empleados (
    id integer NOT NULL,
    clave character varying,
    nombre_pila character varying,
    apellido_paterno character varying,
    apellido_materno character varying,
    imss character varying,
    infonavit character varying,
    curp character varying,
    rfc character varying,
    fecha_nacimiento date,
    fecha_ingreso date,
    gral_escolaridad_id integer DEFAULT 0,
    gral_sexo_id integer DEFAULT 0,
    gral_civil_id integer DEFAULT 0,
    gral_religion_id integer DEFAULT 0,
    gral_sangretipo_id integer DEFAULT 0,
    gral_puesto_id integer DEFAULT 0,
    gral_categ_id integer DEFAULT 0,
    gral_suc_id_empleado integer DEFAULT 0,
    telefono character varying,
    telefono_movil character varying,
    correo_personal character varying,
    gral_pais_id integer DEFAULT 0,
    gral_edo_id integer DEFAULT 0,
    gral_mun_id integer DEFAULT 0,
    calle character varying,
    numero character varying,
    colonia character varying,
    cp character varying,
    contacto_emergencia character varying,
    telefono_emergencia character varying,
    enfermedades text,
    alergias text,
    comentarios text,
    borrado_logico boolean DEFAULT false,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0,
    gral_emp_id integer DEFAULT 0,
    gralsuc_id integer DEFAULT 0,
    comision_agen double precision DEFAULT 0,
    region_id_agen integer DEFAULT 0,
    comision2_agen double precision DEFAULT 0,
    comision3_agen double precision DEFAULT 0,
    comision4_agen double precision DEFAULT 0,
    dias_tope_comision double precision DEFAULT 0,
    dias_tope_comision2 double precision DEFAULT 0,
    dias_tope_comision3 double precision DEFAULT 0,
    monto_tope_comision double precision DEFAULT 0,
    monto_tope_comision2 double precision DEFAULT 0,
    monto_tope_comision3 double precision DEFAULT 0,
    correo_empresa character varying DEFAULT ''::character varying,
    tipo_comision integer DEFAULT 1 NOT NULL,
    no_int character varying DEFAULT ''::character varying,
    nom_regimen_contratacion_id integer DEFAULT 0,
    nom_periodicidad_pago_id integer DEFAULT 0,
    nom_riesgo_puesto_id integer DEFAULT 0,
    nom_tipo_contrato_id integer DEFAULT 0,
    nom_tipo_jornada_id integer DEFAULT 0,
    tes_ban_id integer DEFAULT 0,
    clabe character varying DEFAULT ''::character varying,
    salario_base double precision DEFAULT 0,
    salario_integrado double precision DEFAULT 0,
    registro_patronal character varying DEFAULT ''::character varying,
    genera_nomina boolean DEFAULT false NOT NULL,
    gral_depto_id integer DEFAULT 0
);


ALTER TABLE gral_empleados OWNER TO sumar;

--
-- Name: COLUMN gral_empleados.correo_empresa; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN gral_empleados.correo_empresa IS 'Correo institucionnal asignado por la empresa';


--
-- Name: gral_empleados_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_empleados_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_empleados_id_seq OWNER TO sumar;

--
-- Name: gral_empleados_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_empleados_id_seq OWNED BY gral_empleados.id;


--
-- Name: gral_escolaridads; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE gral_escolaridads (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    borrado_logico boolean DEFAULT false NOT NULL,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0
);


ALTER TABLE gral_escolaridads OWNER TO sumar;

--
-- Name: gral_imptos; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE gral_imptos (
    id integer NOT NULL,
    descripcion character varying NOT NULL,
    iva_1 double precision DEFAULT 0,
    momento_baja timestamp with time zone,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    borrado_logico boolean DEFAULT false NOT NULL,
    gral_usr_id_crea integer DEFAULT 0,
    gral_usr_id_actualiza integer DEFAULT 0,
    gral_usr_id_cancela integer DEFAULT 0
);


ALTER TABLE gral_imptos OWNER TO sumar;

--
-- Name: gral_imptos_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_imptos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_imptos_id_seq OWNER TO sumar;

--
-- Name: gral_imptos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_imptos_id_seq OWNED BY gral_imptos.id;


--
-- Name: gral_mon; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE gral_mon (
    id integer NOT NULL,
    descripcion character varying NOT NULL,
    descripcion_abr character varying DEFAULT ''::character varying,
    borrado_logico boolean DEFAULT false,
    simbolo character varying DEFAULT ''::character varying,
    iso_4217 character varying DEFAULT ''::character varying,
    compras boolean DEFAULT false,
    ventas boolean DEFAULT false,
    iso_4217_anterior character varying DEFAULT ''::character varying
);


ALTER TABLE gral_mon OWNER TO sumar;

--
-- Name: COLUMN gral_mon.compras; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN gral_mon.compras IS 'TRUE=Permitir utilizar en compras';


--
-- Name: COLUMN gral_mon.ventas; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN gral_mon.ventas IS 'TRUE=Permitir utilizar en ventas';


--
-- Name: gral_mon_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_mon_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_mon_id_seq OWNER TO sumar;

--
-- Name: gral_mon_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_mon_id_seq OWNED BY gral_mon.id;


--
-- Name: gral_mun; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE gral_mun (
    titulo character varying,
    estado_id integer,
    pais_id integer,
    id integer NOT NULL
);


ALTER TABLE gral_mun OWNER TO sumar;

--
-- Name: TABLE gral_mun; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON TABLE gral_mun IS 'Tabla que alberga los municipios que pueden ser seleccionados en los aplicativos de el sistema , en base al pais y estado que se seleccione sobre el aplicativo en curso';


--
-- Name: gral_mun_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_mun_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_mun_id_seq OWNER TO sumar;

--
-- Name: gral_mun_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_mun_id_seq OWNED BY gral_mun.id;


--
-- Name: gral_pais; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE gral_pais (
    id integer NOT NULL,
    titulo character varying,
    abreviacion character varying
);


ALTER TABLE gral_pais OWNER TO sumar;

--
-- Name: TABLE gral_pais; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON TABLE gral_pais IS 'Tabla que alberga los paises que pueden ser seleccionados en los aplicativos del sistema';


--
-- Name: gral_pais_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_pais_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_pais_id_seq OWNER TO sumar;

--
-- Name: gral_pais_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_pais_id_seq OWNED BY gral_pais.id;


--
-- Name: gral_puestos; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE gral_puestos (
    id integer NOT NULL,
    titulo character varying,
    borrado_logico boolean DEFAULT false NOT NULL,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0
);


ALTER TABLE gral_puestos OWNER TO sumar;

--
-- Name: gral_puestos_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_puestos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_puestos_id_seq OWNER TO sumar;

--
-- Name: gral_puestos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_puestos_id_seq OWNED BY gral_puestos.id;


--
-- Name: gral_religions; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE gral_religions (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    borrado_logico boolean DEFAULT false NOT NULL,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0
);


ALTER TABLE gral_religions OWNER TO sumar;

--
-- Name: gral_religions_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_religions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_religions_id_seq OWNER TO sumar;

--
-- Name: gral_religions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_religions_id_seq OWNED BY gral_religions.id;


--
-- Name: gral_rol_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_rol_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_rol_id_seq OWNER TO sumar;

--
-- Name: gral_rol_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_rol_id_seq OWNED BY gral_rol.id;


--
-- Name: gral_sangretipos; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE gral_sangretipos (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    borrado_logico boolean DEFAULT false NOT NULL,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0
);


ALTER TABLE gral_sangretipos OWNER TO sumar;

--
-- Name: gral_sangretipos_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_sangretipos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_sangretipos_id_seq OWNER TO sumar;

--
-- Name: gral_sangretipos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_sangretipos_id_seq OWNED BY gral_sangretipos.id;


--
-- Name: gral_sexos; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE gral_sexos (
    id integer NOT NULL,
    titulo character varying,
    borrado_logico boolean DEFAULT false NOT NULL
);


ALTER TABLE gral_sexos OWNER TO sumar;

--
-- Name: gral_sexos_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_sexos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_sexos_id_seq OWNER TO sumar;

--
-- Name: gral_sexos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_sexos_id_seq OWNED BY gral_sexos.id;


--
-- Name: gral_suc; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE gral_suc (
    id integer NOT NULL,
    titulo character varying(20) NOT NULL,
    cp character varying(6) NOT NULL,
    colonia character varying(60) NOT NULL,
    calle character varying NOT NULL,
    numero_interior character varying(10),
    numero_exterior character varying(10),
    borrado_logico boolean DEFAULT false NOT NULL,
    empresa_id integer NOT NULL,
    momento_creacion timestamp with time zone NOT NULL,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_pais_id integer,
    gral_edo_id integer,
    gral_mun_id integer,
    gral_impto_id integer DEFAULT 1,
    email character varying DEFAULT ''::character varying,
    clave character varying DEFAULT ''::character varying NOT NULL,
    CONSTRAINT chk_gral_impto_id CHECK ((gral_impto_id > 0))
);


ALTER TABLE gral_suc OWNER TO sumar;

--
-- Name: TABLE gral_suc; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON TABLE gral_suc IS 'Tabla que alberga todas las sucursales que maneja determinada empresa';


--
-- Name: gral_suc_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_suc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_suc_id_seq OWNER TO sumar;

--
-- Name: gral_suc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_suc_id_seq OWNED BY gral_suc.id;


--
-- Name: gral_tc_url; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE gral_tc_url (
    id integer NOT NULL,
    url character varying NOT NULL,
    institucion character varying DEFAULT ''::character varying NOT NULL
);


ALTER TABLE gral_tc_url OWNER TO sumar;

--
-- Name: gral_tc_url_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_tc_url_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_tc_url_id_seq OWNER TO sumar;

--
-- Name: gral_tc_url_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_tc_url_id_seq OWNED BY gral_tc_url.id;


--
-- Name: gral_usr_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_usr_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_usr_id_seq OWNER TO sumar;

--
-- Name: gral_usr_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_usr_id_seq OWNED BY gral_usr.id;


--
-- Name: gral_usr_rol_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_usr_rol_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_usr_rol_id_seq OWNER TO sumar;

--
-- Name: gral_usr_rol_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_usr_rol_id_seq OWNED BY gral_usr_rol.id;


--
-- Name: gral_usr_suc; Type: TABLE; Schema: public; Owner: sumar; Tablespace: 
--

CREATE TABLE gral_usr_suc (
    id integer NOT NULL,
    gral_usr_id integer NOT NULL,
    gral_suc_id integer NOT NULL
);


ALTER TABLE gral_usr_suc OWNER TO sumar;

--
-- Name: TABLE gral_usr_suc; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON TABLE gral_usr_suc IS 'Relacion de los usuarios que existen por sucursal';


--
-- Name: gral_usr_suc_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_usr_suc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_usr_suc_id_seq OWNER TO sumar;

--
-- Name: gral_usr_suc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_usr_suc_id_seq OWNED BY gral_usr_suc.id;


--
-- Name: users; Type: VIEW; Schema: public; Owner: sumar
--

CREATE VIEW users AS
 SELECT gral_usr.username,
    gral_usr.password,
    gral_usr.enabled
   FROM gral_usr;


ALTER TABLE users OWNER TO sumar;

--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_monedavers ALTER COLUMN id SET DEFAULT nextval('erp_monedavers_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_categ ALTER COLUMN id SET DEFAULT nextval('gral_categ_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_civils ALTER COLUMN id SET DEFAULT nextval('gral_civils_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_deptos ALTER COLUMN id SET DEFAULT nextval('gral_deptos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_edo ALTER COLUMN id SET DEFAULT nextval('gral_edo_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_emails ALTER COLUMN id SET DEFAULT nextval('gral_emails_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_emp ALTER COLUMN id SET DEFAULT nextval('gral_emp_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_emp_leyenda ALTER COLUMN id SET DEFAULT nextval('gral_emp_leyenda_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_empleados ALTER COLUMN id SET DEFAULT nextval('gral_empleados_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_imptos ALTER COLUMN id SET DEFAULT nextval('gral_imptos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_mon ALTER COLUMN id SET DEFAULT nextval('gral_mon_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_mun ALTER COLUMN id SET DEFAULT nextval('gral_mun_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_pais ALTER COLUMN id SET DEFAULT nextval('gral_pais_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_puestos ALTER COLUMN id SET DEFAULT nextval('gral_puestos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_religions ALTER COLUMN id SET DEFAULT nextval('gral_religions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_rol ALTER COLUMN id SET DEFAULT nextval('gral_rol_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_sangretipos ALTER COLUMN id SET DEFAULT nextval('gral_sangretipos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_sexos ALTER COLUMN id SET DEFAULT nextval('gral_sexos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_suc ALTER COLUMN id SET DEFAULT nextval('gral_suc_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_tc_url ALTER COLUMN id SET DEFAULT nextval('gral_tc_url_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_usr ALTER COLUMN id SET DEFAULT nextval('gral_usr_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_usr_rol ALTER COLUMN id SET DEFAULT nextval('gral_usr_rol_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_usr_suc ALTER COLUMN id SET DEFAULT nextval('gral_usr_suc_id_seq'::regclass);


--
-- Data for Name: erp_monedavers; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY erp_monedavers (id, valor, momento_creacion, moneda_id, version) FROM stdin;
1	18.9116999999999997	2016-08-04 10:15:30.181524-04	2	DOF
\.


--
-- Name: erp_monedavers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('erp_monedavers_id_seq', 1, true);


--
-- Data for Name: gral_categ; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_categ (id, titulo, sueldo_por_hora, sueldo_por_horas_ext, gral_puesto_id, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja, gral_emp_id, gral_suc_id) FROM stdin;
1	A	1	1	1	f	2013-02-26 19:16:06.219619-05	\N	\N	1	0	0	1	1
2	B	1	1	2	f	2013-02-26 19:16:18.268615-05	\N	\N	1	0	0	1	1
\.


--
-- Name: gral_categ_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_categ_id_seq', 1, false);


--
-- Data for Name: gral_civils; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_civils (id, titulo, borrado_logico) FROM stdin;
1	SOLTERO	f
2	CASADO	f
3	VIUDO	f
4	DIVORCIADO	f
5	UNION LIBRE	f
\.


--
-- Name: gral_civils_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_civils_id_seq', 1, false);


--
-- Data for Name: gral_deptos; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_deptos (id, titulo, costo_prorrateo, vigente, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja, gral_emp_id, gral_suc_id) FROM stdin;
1	VENTAS	0	t	f	2016-06-01 22:34:32.413767-04	\N	\N	1	0	0	1	1
\.


--
-- Name: gral_deptos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_deptos_id_seq', 1, true);


--
-- Data for Name: gral_edo; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_edo (id, titulo, abreviacion, pais_id) FROM stdin;
1	Aguascalientes	Ags.	2
2	Baja California	BC	2
3	Baja California Sur	BCS	2
4	Campeche	Camp.	2
5	Coahuila de Zaragoza	Coah.	2
6	Colima	Col.	2
7	Chiapas	Chis.	2
8	Chihuahua	Chih.	2
10	Durango	Dgo.	2
11	Guanajuato	Gto.	2
12	Guerrero	Gro.	2
13	Hidalgo	Hgo.	2
14	Jalisco	Jal.	2
15	México	Mex.	2
16	Michoacán de Ocampo	Mich.	2
17	Morelos	Mor.	2
18	Nayarit	Nay.	2
19	Nuevo León	NL	2
20	Oaxaca	Oax.	2
21	Puebla	Pue.	2
22	Querétaro	Qro.	2
23	Quintana Roo	Q. Roo	2
24	San Luis Potosí	SLP	2
25	Sinaloa	Sin.	2
26	Sonora	Son.	2
27	Tabasco	Tab.	2
28	Tamaulipas	Tamps.	2
29	Tlaxcala	Tlax.	2
30	Veracruz de Ignacio de la Llave	Ver.	2
31	Yucatán	Yuc.	2
32	Zacatecas	Zac.	2
33	xx	\N	1
9	Ciudad de México	CDMX	2
\.


--
-- Name: gral_edo_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_edo_id_seq', 1, false);


--
-- Data for Name: gral_emails; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_emails (id, gral_emp_id, gral_suc_id, email, passwd, borrado_logico, port, host) FROM stdin;
1	1	1	FACTURAS.KUPSA@GMAIL.COM	4b4dp3t3r	f	587	smtp.gmail.com
\.


--
-- Name: gral_emails_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_emails_id_seq', 1, false);


--
-- Data for Name: gral_emp; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_emp (id, titulo, colonia, cp, calle, rfc, numero_interior, numero_exterior, momento_creacion, momento_actualizacion, momento_baja, telefono, borrado_logico, estado_id, municipio_id, pais_id, regimen_fiscal, incluye_produccion, email_compras, pass_email_compras, pagina_web, incluye_contabilidad, nivel_cta, incluye_crm, encluye_envasado, control_exis_pres, lista_precio_clientes, tipo_facturacion, pac_facturacion, ambiente_facturacion, gral_impto_id, transportista, tasa_retencion, nomina, no_id, incluye_log, gral_tc_url_id) FROM stdin;
1	AGNUX PRUEBAS S.A. DE C.V.	LA ENCARNACION	66633	AV. IGNACIO SEPULVEDA	AAA010101AAA	\N	109	2010-12-21 18:30:57.599-05	2015-02-04 19:00:00-05	\N	(1081)13340206	f	19	953	2	REGIMEN GENERAL DE LEY PERSONAS MORALES	f			www.kathionchemie.com.mx	f	5	f	f	t	f	cfditf	2	f	1	f	4	t	1	f	1
\.


--
-- Name: gral_emp_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_emp_id_seq', 1, true);


--
-- Data for Name: gral_emp_leyenda; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_emp_leyenda (id, leyenda, gral_emp_id) FROM stdin;
\.


--
-- Name: gral_emp_leyenda_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_emp_leyenda_id_seq', 1, false);


--
-- Data for Name: gral_empleados; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_empleados (id, clave, nombre_pila, apellido_paterno, apellido_materno, imss, infonavit, curp, rfc, fecha_nacimiento, fecha_ingreso, gral_escolaridad_id, gral_sexo_id, gral_civil_id, gral_religion_id, gral_sangretipo_id, gral_puesto_id, gral_categ_id, gral_suc_id_empleado, telefono, telefono_movil, correo_personal, gral_pais_id, gral_edo_id, gral_mun_id, calle, numero, colonia, cp, contacto_emergencia, telefono_emergencia, enfermedades, alergias, comentarios, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja, gral_emp_id, gralsuc_id, comision_agen, region_id_agen, comision2_agen, comision3_agen, comision4_agen, dias_tope_comision, dias_tope_comision2, dias_tope_comision3, monto_tope_comision, monto_tope_comision2, monto_tope_comision3, correo_empresa, tipo_comision, no_int, nom_regimen_contratacion_id, nom_periodicidad_pago_id, nom_riesgo_puesto_id, nom_tipo_contrato_id, nom_tipo_jornada_id, tes_ban_id, clabe, salario_base, salario_integrado, registro_patronal, genera_nomina, gral_depto_id) FROM stdin;
1	1	JUAN ARTURO	RIOS	VARGAS	43008368748	\N	RIVJ830922HNLSRN06	\N	1983-09-22	2016-04-01	3	1	1	1	1	1	1	1				2	1	1	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	\N	1	1	0	1	1	0	0	0	0	0	0	0	0	0	0	0		1		0	0	0	0	0	0		0	0		f	1
\.


--
-- Name: gral_empleados_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_empleados_id_seq', 1, false);


--
-- Data for Name: gral_escolaridads; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_escolaridads (id, titulo, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja, gral_emp_id, gral_suc_id) FROM stdin;
1	PRIMARIA	f	2013-02-26 19:13:43.541816-05	\N	\N	1	0	0	1	1
2	SECUNDARIA	f	2013-02-26 19:13:56.905112-05	\N	\N	1	0	0	1	1
3	PREPARATORIA	f	2013-02-26 19:14:11.535556-05	\N	\N	1	0	0	1	1
4	UNIVERSIDAD	f	2013-02-26 19:14:31.708711-05	\N	\N	1	0	0	1	1
\.


--
-- Data for Name: gral_imptos; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_imptos (id, descripcion, iva_1, momento_baja, momento_creacion, momento_actualizacion, borrado_logico, gral_usr_id_crea, gral_usr_id_actualiza, gral_usr_id_cancela) FROM stdin;
1	IVA 16	0.160000000000000003	\N	2009-12-31 19:00:00-05	2009-12-31 20:00:00-05	f	0	0	0
2	IVA TASA 0	0	\N	2009-12-30 19:00:00-05	2009-12-31 21:00:00-05	f	0	0	0
3	IVA 11%	11	\N	2009-12-31 23:00:00-05	2009-12-31 17:00:00-05	f	0	0	0
4	EXENTO	0	\N	2009-12-31 16:00:00-05	2009-12-31 15:00:00-05	f	0	0	0
\.


--
-- Name: gral_imptos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_imptos_id_seq', 4, true);


--
-- Data for Name: gral_mon; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_mon (id, descripcion, descripcion_abr, borrado_logico, simbolo, iso_4217, compras, ventas, iso_4217_anterior) FROM stdin;
4	IEN	\N	t			f	f	
5	NUEVA MONEDA	\N	t			f	f	
6	NUEVA MONEDA 2	\N	t			f	f	
7	NUEVA MONEDA 3	\N	t			f	f	
8	NUEVA MONEDA 4	\N	t			f	f	
9	NUEVA MONEDA 5	\N	t			f	f	
1	Pesos	M.N.	f	$	MXN	t	t	MXP
2	Dolares	USD	f	USD	USD	t	t	USD
3	Euros	EUR	f	€\n	EUR	t	f	EUR
\.


--
-- Name: gral_mon_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_mon_id_seq', 1, false);


--
-- Data for Name: gral_mun; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_mun (titulo, estado_id, pais_id, id) FROM stdin;
Aguascalientes	1	2	1
Asientos	1	2	2
Calvillo	1	2	3
Cosío	1	2	4
Jesús María	1	2	5
Pabellón de Arteaga	1	2	6
Rincón de Romos	1	2	7
San José de Gracia	1	2	8
Tepezalá	1	2	9
El Llano	1	2	10
San Francisco de los Romo	1	2	11
Ensenada	2	2	12
Mexicali	2	2	13
Tecate	2	2	14
Tijuana	2	2	15
Playas de Rosarito	2	2	16
Comondú	3	2	17
Mulegé	3	2	18
La Paz	3	2	19
Los Cabos	3	2	20
Loreto	3	2	21
Calkiní	4	2	22
Campeche	4	2	23
Carmen	4	2	24
Champotón	4	2	25
Hecelchakán	4	2	26
Hopelchén	4	2	27
Palizada	4	2	28
Tenabo	4	2	29
Escárcega	4	2	30
Calakmul	4	2	31
Candelaria	4	2	32
Abasolo	5	2	33
Acuña	5	2	34
Allende	5	2	35
Arteaga	5	2	36
Candela	5	2	37
Castaños	5	2	38
Cuatro Ciénegas	5	2	39
Escobedo	5	2	40
Francisco I. Madero	5	2	41
Frontera	5	2	42
General Cepeda	5	2	43
Guerrero	5	2	44
Hidalgo	5	2	45
Jiménez	5	2	46
Juárez	5	2	47
Lamadrid	5	2	48
Matamoros	5	2	49
Monclova	5	2	50
Morelos	5	2	51
Múzquiz	5	2	52
Nadadores	5	2	53
Nava	5	2	54
Ocampo	5	2	55
Parras	5	2	56
Piedras Negras	5	2	57
Progreso	5	2	58
Ramos Arizpe	5	2	59
Sabinas	5	2	60
Sacramento	5	2	61
Saltillo	5	2	62
San Buenaventura	5	2	63
San Juan de Sabinas	5	2	64
San Pedro	5	2	65
Sierra Mojada	5	2	66
Torreón	5	2	67
Viesca	5	2	68
Villa Unión	5	2	69
Zaragoza	5	2	70
Armería	6	2	71
Colima	6	2	72
Comala	6	2	73
Coquimatlán	6	2	74
Cuauhtémoc	6	2	75
Ixtlahuacán	6	2	76
Manzanillo	6	2	77
Minatitlán	6	2	78
Tecomán	6	2	79
Villa de Álvarez	6	2	80
Acacoyagua	7	2	81
Acala	7	2	82
Acapetahua	7	2	83
Altamirano	7	2	84
Amatán	7	2	85
Amatenango de la Frontera	7	2	86
Amatenango del Valle	7	2	87
Angel Albino Corzo	7	2	88
Arriaga	7	2	89
Bejucal de Ocampo	7	2	90
Bella Vista	7	2	91
Berriozábal	7	2	92
Bochil	7	2	93
El Bosque	7	2	94
Cacahoatán	7	2	95
Catazajá	7	2	96
Cintalapa	7	2	97
Coapilla	7	2	98
Comitán de Domínguez	7	2	99
La Concordia	7	2	100
Copainalá	7	2	101
Chalchihuitán	7	2	102
Chamula	7	2	103
Chanal	7	2	104
Chapultenango	7	2	105
Chenalhó	7	2	106
Chiapa de Corzo	7	2	107
Chiapilla	7	2	108
Chicoasén	7	2	109
Chicomuselo	7	2	110
Chilón	7	2	111
Escuintla	7	2	112
Francisco León	7	2	113
Frontera Comalapa	7	2	114
Frontera Hidalgo	7	2	115
La Grandeza	7	2	116
Huehuetán	7	2	117
Huixtán	7	2	118
Huitiupán	7	2	119
Huixtla	7	2	120
La Independencia	7	2	121
Ixhuatán	7	2	122
Ixtacomitán	7	2	123
Ixtapa	7	2	124
Ixtapangajoya	7	2	125
Jiquipilas	7	2	126
Jitotol	7	2	127
Juárez	7	2	128
Larráinzar	7	2	129
La Libertad	7	2	130
Mapastepec	7	2	131
Las Margaritas	7	2	132
Mazapa de Madero	7	2	133
Mazatán	7	2	134
Metapa	7	2	135
Mitontic	7	2	136
Motozintla	7	2	137
Nicolás Ruíz	7	2	138
Ocosingo	7	2	139
Ocotepec	7	2	140
Ocozocoautla de Espinosa	7	2	141
Ostuacán	7	2	142
Osumacinta	7	2	143
Oxchuc	7	2	144
Palenque	7	2	145
Pantelhó	7	2	146
Pantepec	7	2	147
Pichucalco	7	2	148
Pijijiapan	7	2	149
El Porvenir	7	2	150
Villa Comaltitlán	7	2	151
Pueblo Nuevo Solistahuacán	7	2	152
Rayón	7	2	153
Reforma	7	2	154
Las Rosas	7	2	155
Sabanilla	7	2	156
Salto de Agua	7	2	157
San Cristóbal de las Casas	7	2	158
San Fernando	7	2	159
Siltepec	7	2	160
Simojovel	7	2	161
Sitalá	7	2	162
Socoltenango	7	2	163
Solosuchiapa	7	2	164
Soyaló	7	2	165
Suchiapa	7	2	166
Suchiate	7	2	167
Sunuapa	7	2	168
Tapachula	7	2	169
Tapalapa	7	2	170
Tapilula	7	2	171
Tecpatán	7	2	172
Tenejapa	7	2	173
Teopisca	7	2	174
Tila	7	2	175
Tonalá	7	2	176
Totolapa	7	2	177
La Trinitaria	7	2	178
Tumbalá	7	2	179
Tuxtla Gutiérrez	7	2	180
Tuxtla Chico	7	2	181
Tuzantán	7	2	182
Tzimol	7	2	183
Unión Juárez	7	2	184
Venustiano Carranza	7	2	185
Villa Corzo	7	2	186
Villaflores	7	2	187
Yajalón	7	2	188
San Lucas	7	2	189
Zinacantán	7	2	190
San Juan Cancuc	7	2	191
Aldama	7	2	192
Benemérito de las Américas	7	2	193
Maravilla Tenejapa	7	2	194
Marqués de Comillas	7	2	195
Montecristo de Guerrero	7	2	196
San Andrés Duraznal	7	2	197
Santiago el Pinar	7	2	198
Ahumada	8	2	199
Aldama	8	2	200
Allende	8	2	201
Aquiles Serdán	8	2	202
Ascensión	8	2	203
Bachíniva	8	2	204
Balleza	8	2	205
Batopilas	8	2	206
Bocoyna	8	2	207
Buenaventura	8	2	208
Camargo	8	2	209
Carichí	8	2	210
Casas Grandes	8	2	211
Coronado	8	2	212
Coyame del Sotol	8	2	213
La Cruz	8	2	214
Cuauhtémoc	8	2	215
Cusihuiriachi	8	2	216
Chihuahua	8	2	217
Chínipas	8	2	218
Delicias	8	2	219
Dr. Belisario Domínguez	8	2	220
Galeana	8	2	221
Santa Isabel	8	2	222
Gómez Farías	8	2	223
Gran Morelos	8	2	224
Guachochi	8	2	225
Guadalupe	8	2	226
Guadalupe y Calvo	8	2	227
Guazapares	8	2	228
Guerrero	8	2	229
Hidalgo del Parral	8	2	230
Huejotitán	8	2	231
Ignacio Zaragoza	8	2	232
Janos	8	2	233
Jiménez	8	2	234
Juárez	8	2	235
Julimes	8	2	236
López	8	2	237
Madera	8	2	238
Maguarichi	8	2	239
Manuel Benavides	8	2	240
Matachí	8	2	241
Matamoros	8	2	242
Meoqui	8	2	243
Morelos	8	2	244
Moris	8	2	245
Namiquipa	8	2	246
Nonoava	8	2	247
Nuevo Casas Grandes	8	2	248
Ocampo	8	2	249
Ojinaga	8	2	250
Praxedis G. Guerrero	8	2	251
Riva Palacio	8	2	252
Rosales	8	2	253
Rosario	8	2	254
San Francisco de Borja	8	2	255
San Francisco de Conchos	8	2	256
San Francisco del Oro	8	2	257
Santa Bárbara	8	2	258
Satevó	8	2	259
Saucillo	8	2	260
Temósachic	8	2	261
El Tule	8	2	262
Urique	8	2	263
Uruachi	8	2	264
Valle de Zaragoza	8	2	265
Azcapotzalco	9	2	266
Coyoacán	9	2	267
Cuajimalpa de Morelos	9	2	268
Gustavo A. Madero	9	2	269
Iztacalco	9	2	270
Iztapalapa	9	2	271
La Magdalena Contreras	9	2	272
Milpa Alta	9	2	273
Álvaro Obregón	9	2	274
Tláhuac	9	2	275
Tlalpan	9	2	276
Xochimilco	9	2	277
Benito Juárez	9	2	278
Cuauhtémoc	9	2	279
Miguel Hidalgo	9	2	280
Venustiano Carranza	9	2	281
Canatlán	10	2	282
Canelas	10	2	283
Coneto de Comonfort	10	2	284
Cuencamé	10	2	285
Durango	10	2	286
General Simón Bolívar	10	2	287
Gómez Palacio	10	2	288
Guadalupe Victoria	10	2	289
Guanaceví	10	2	290
Hidalgo	10	2	291
Indé	10	2	292
Lerdo	10	2	293
Mapimí	10	2	294
Mezquital	10	2	295
Nazas	10	2	296
Nombre de Dios	10	2	297
Ocampo	10	2	298
El Oro	10	2	299
Otáez	10	2	300
Pánuco de Coronado	10	2	301
Peñón Blanco	10	2	302
Poanas	10	2	303
Pueblo Nuevo	10	2	304
Rodeo	10	2	305
San Bernardo	10	2	306
San Dimas	10	2	307
San Juan de Guadalupe	10	2	308
San Juan del Río	10	2	309
San Luis del Cordero	10	2	310
San Pedro del Gallo	10	2	311
Santa Clara	10	2	312
Santiago Papasquiaro	10	2	313
Súchil	10	2	314
Tamazula	10	2	315
Tepehuanes	10	2	316
Tlahualilo	10	2	317
Topia	10	2	318
Vicente Guerrero	10	2	319
Nuevo Ideal	10	2	320
Abasolo	11	2	321
Acámbaro	11	2	322
San Miguel de Allende	11	2	323
Apaseo el Alto	11	2	324
Apaseo el Grande	11	2	325
Atarjea	11	2	326
Celaya	11	2	327
Manuel Doblado	11	2	328
Comonfort	11	2	329
Coroneo	11	2	330
Cortazar	11	2	331
Cuerámaro	11	2	332
Doctor Mora	11	2	333
Dolores Hidalgo Cuna de la Independencia Nacional	11	2	334
Guanajuato	11	2	335
Huanímaro	11	2	336
Irapuato	11	2	337
Jaral del Progreso	11	2	338
Jerécuaro	11	2	339
León	11	2	340
Moroleón	11	2	341
Ocampo	11	2	342
Pénjamo	11	2	343
Pueblo Nuevo	11	2	344
Purísima del Rincón	11	2	345
Romita	11	2	346
Salamanca	11	2	347
Salvatierra	11	2	348
San Diego de la Unión	11	2	349
San Felipe	11	2	350
San Francisco del Rincón	11	2	351
San José Iturbide	11	2	352
San Luis de la Paz	11	2	353
Santa Catarina	11	2	354
Santa Cruz de Juventino Rosas	11	2	355
Santiago Maravatío	11	2	356
Silao	11	2	357
Tarandacuao	11	2	358
Tarimoro	11	2	359
Tierra Blanca	11	2	360
Uriangato	11	2	361
Valle de Santiago	11	2	362
Victoria	11	2	363
Villagrán	11	2	364
Xichú	11	2	365
Yuriria	11	2	366
Acapulco de Juárez	12	2	367
Ahuacuotzingo	12	2	368
Ajuchitlán del Progreso	12	2	369
Alcozauca de Guerrero	12	2	370
Alpoyeca	12	2	371
Apaxtla	12	2	372
Arcelia	12	2	373
Atenango del Río	12	2	374
Atlamajalcingo del Monte	12	2	375
Atlixtac	12	2	376
Atoyac de Álvarez	12	2	377
Ayutla de los Libres	12	2	378
Azoyú	12	2	379
Benito Juárez	12	2	380
Buenavista de Cuéllar	12	2	381
Coahuayutla de José María Izazaga	12	2	382
Cocula	12	2	383
Copala	12	2	384
Copalillo	12	2	385
Copanatoyac	12	2	386
Coyuca de Benítez	12	2	387
Coyuca de Catalán	12	2	388
Cuajinicuilapa	12	2	389
Cualác	12	2	390
Cuautepec	12	2	391
Cuetzala del Progreso	12	2	392
Cutzamala de Pinzón	12	2	393
Chilapa de Álvarez	12	2	394
Chilpancingo de los Bravo	12	2	395
Florencio Villarreal	12	2	396
General Canuto A. Neri	12	2	397
General Heliodoro Castillo	12	2	398
Huamuxtitlán	12	2	399
Huitzuco de los Figueroa	12	2	400
Iguala de la Independencia	12	2	401
Igualapa	12	2	402
Ixcateopan de Cuauhtémoc	12	2	403
Zihuatanejo de Azueta	12	2	404
Juan R. Escudero	12	2	405
Leonardo Bravo	12	2	406
Malinaltepec	12	2	407
Mártir de Cuilapan	12	2	408
Metlatónoc	12	2	409
Mochitlán	12	2	410
Olinalá	12	2	411
Ometepec	12	2	412
Pedro Ascencio Alquisiras	12	2	413
Petatlán	12	2	414
Pilcaya	12	2	415
Pungarabato	12	2	416
Quechultenango	12	2	417
San Luis Acatlán	12	2	418
San Marcos	12	2	419
San Miguel Totolapan	12	2	420
Taxco de Alarcón	12	2	421
Tecoanapa	12	2	422
Técpan de Galeana	12	2	423
Teloloapan	12	2	424
Tepecoacuilco de Trujano	12	2	425
Tetipac	12	2	426
Tixtla de Guerrero	12	2	427
Tlacoachistlahuaca	12	2	428
Tlacoapa	12	2	429
Tlalchapa	12	2	430
Tlalixtaquilla de Maldonado	12	2	431
Tlapa de Comonfort	12	2	432
Tlapehuala	12	2	433
La Unión de Isidoro Montes de Oca	12	2	434
Xalpatláhuac	12	2	435
Xochihuehuetlán	12	2	436
Xochistlahuaca	12	2	437
Zapotitlán Tablas	12	2	438
Zirándaro	12	2	439
Zitlala	12	2	440
Eduardo Neri	12	2	441
Acatepec	12	2	442
Marquelia	12	2	443
Cochoapa el Grande	12	2	444
José Joaquin de Herrera	12	2	445
Juchitán	12	2	446
Iliatenco	12	2	447
Acatlán	13	2	448
Acaxochitlán	13	2	449
Actopan	13	2	450
Agua Blanca de Iturbide	13	2	451
Ajacuba	13	2	452
Alfajayucan	13	2	453
Almoloya	13	2	454
Apan	13	2	455
El Arenal	13	2	456
Atitalaquia	13	2	457
Atlapexco	13	2	458
Atotonilco el Grande	13	2	459
Atotonilco de Tula	13	2	460
Calnali	13	2	461
Cardonal	13	2	462
Cuautepec de Hinojosa	13	2	463
Chapantongo	13	2	464
Chapulhuacán	13	2	465
Chilcuautla	13	2	466
Eloxochitlán	13	2	467
Emiliano Zapata	13	2	468
Epazoyucan	13	2	469
Francisco I. Madero	13	2	470
Huasca de Ocampo	13	2	471
Huautla	13	2	472
Huazalingo	13	2	473
Huehuetla	13	2	474
Huejutla de Reyes	13	2	475
Huichapan	13	2	476
Ixmiquilpan	13	2	477
Jacala de Ledezma	13	2	478
Jaltocán	13	2	479
Juárez Hidalgo	13	2	480
Lolotla	13	2	481
Metepec	13	2	482
San Agustín Metzquititlán	13	2	483
Metztitlán	13	2	484
Mineral del Chico	13	2	485
Mineral del Monte	13	2	486
La Misión	13	2	487
Mixquiahuala de Juárez	13	2	488
Molango de Escamilla	13	2	489
Nicolás Flores	13	2	490
Nopala de Villagrán	13	2	491
Omitlán de Juárez	13	2	492
San Felipe Orizatlán	13	2	493
Pacula	13	2	494
Pachuca de Soto	13	2	495
Pisaflores	13	2	496
Progreso de Obregón	13	2	497
Mineral de la Reforma	13	2	498
San Agustín Tlaxiaca	13	2	499
San Bartolo Tutotepec	13	2	500
San Salvador	13	2	501
Santiago de Anaya	13	2	502
Santiago Tulantepec de Lugo Guerrero	13	2	503
Singuilucan	13	2	504
Tasquillo	13	2	505
Tecozautla	13	2	506
Tenango de Doria	13	2	507
Tepeapulco	13	2	508
Tepehuacán de Guerrero	13	2	509
Tepeji del Río de Ocampo	13	2	510
Tepetitlán	13	2	511
Tetepango	13	2	512
Villa de Tezontepec	13	2	513
Tezontepec de Aldama	13	2	514
Tianguistengo	13	2	515
Tizayuca	13	2	516
Tlahuelilpan	13	2	517
Tlahuiltepa	13	2	518
Tlanalapa	13	2	519
Tlanchinol	13	2	520
Tlaxcoapan	13	2	521
Tolcayuca	13	2	522
Tula de Allende	13	2	523
Tulancingo de Bravo	13	2	524
Xochiatipan	13	2	525
Xochicoatlán	13	2	526
Yahualica	13	2	527
Zacualtipán de Ángeles	13	2	528
Zapotlán de Juárez	13	2	529
Zempoala	13	2	530
Zimapán	13	2	531
Acatic	14	2	532
Acatlán de Juárez	14	2	533
Ahualulco de Mercado	14	2	534
Amacueca	14	2	535
Amatitán	14	2	536
Ameca	14	2	537
San Juanito de Escobedo	14	2	538
Arandas	14	2	539
El Arenal	14	2	540
Atemajac de Brizuela	14	2	541
Atengo	14	2	542
Atenguillo	14	2	543
Atotonilco el Alto	14	2	544
Atoyac	14	2	545
Autlán de Navarro	14	2	546
Ayotlán	14	2	547
Ayutla	14	2	548
La Barca	14	2	549
Bolaños	14	2	550
Cabo Corrientes	14	2	551
Casimiro Castillo	14	2	552
Cihuatlán	14	2	553
Zapotlán el Grande	14	2	554
Cocula	14	2	555
Colotlán	14	2	556
Concepción de Buenos Aires	14	2	557
Cuautitlán de García Barragán	14	2	558
Cuautla	14	2	559
Cuquío	14	2	560
Chapala	14	2	561
Chimaltitán	14	2	562
Chiquilistlán	14	2	563
Degollado	14	2	564
Ejutla	14	2	565
Encarnación de Díaz	14	2	566
Etzatlán	14	2	567
El Grullo	14	2	568
Guachinango	14	2	569
Guadalajara	14	2	570
Hostotipaquillo	14	2	571
Huejúcar	14	2	572
Huejuquilla el Alto	14	2	573
La Huerta	14	2	574
Ixtlahuacán de los Membrillos	14	2	575
Ixtlahuacán del Río	14	2	576
Jalostotitlán	14	2	577
Jamay	14	2	578
Jesús María	14	2	579
Jilotlán de los Dolores	14	2	580
Jocotepec	14	2	581
Juanacatlán	14	2	582
Juchitlán	14	2	583
Lagos de Moreno	14	2	584
El Limón	14	2	585
Magdalena	14	2	586
Santa María del Oro	14	2	587
La Manzanilla de la Paz	14	2	588
Mascota	14	2	589
Mazamitla	14	2	590
Mexticacán	14	2	591
Mezquitic	14	2	592
Mixtlán	14	2	593
Ocotlán	14	2	594
Ojuelos de Jalisco	14	2	595
Pihuamo	14	2	596
Poncitlán	14	2	597
Puerto Vallarta	14	2	598
Villa Purificación	14	2	599
Quitupan	14	2	600
El Salto	14	2	601
San Cristóbal de la Barranca	14	2	602
San Diego de Alejandría	14	2	603
San Juan de los Lagos	14	2	604
San Julián	14	2	605
San Marcos	14	2	606
San Martín de Bolaños	14	2	607
San Martín Hidalgo	14	2	608
San Miguel el Alto	14	2	609
Gómez Farías	14	2	610
San Sebastián del Oeste	14	2	611
Santa María de los Ángeles	14	2	612
Sayula	14	2	613
Tala	14	2	614
Talpa de Allende	14	2	615
Tamazula de Gordiano	14	2	616
Tapalpa	14	2	617
Tecalitlán	14	2	618
Tecolotlán	14	2	619
Techaluta de Montenegro	14	2	620
Tenamaxtlán	14	2	621
Teocaltiche	14	2	622
Teocuitatlán de Corona	14	2	623
Tepatitlán de Morelos	14	2	624
Tequila	14	2	625
Teuchitlán	14	2	626
Tizapán el Alto	14	2	627
Tlajomulco de Zúñiga	14	2	628
Tlaquepaque	14	2	629
Tolimán	14	2	630
Tomatlán	14	2	631
Tonalá	14	2	632
Tonaya	14	2	633
Tonila	14	2	634
Totatiche	14	2	635
Tototlán	14	2	636
Tuxcacuesco	14	2	637
Tuxcueca	14	2	638
Tuxpan	14	2	639
Unión de San Antonio	14	2	640
Unión de Tula	14	2	641
Valle de Guadalupe	14	2	642
Valle de Juárez	14	2	643
San Gabriel	14	2	644
Villa Corona	14	2	645
Villa Guerrero	14	2	646
Villa Hidalgo	14	2	647
Cañadas de Obregón	14	2	648
Yahualica de González Gallo	14	2	649
Zacoalco de Torres	14	2	650
Zapopan	14	2	651
Zapotiltic	14	2	652
Zapotitlán de Vadillo	14	2	653
Zapotlán del Rey	14	2	654
Zapotlanejo	14	2	655
San Ignacio Cerro Gordo	14	2	656
Acambay	15	2	657
Acolman	15	2	658
Aculco	15	2	659
Almoloya de Alquisiras	15	2	660
Almoloya de Juárez	15	2	661
Almoloya del Río	15	2	662
Amanalco	15	2	663
Amatepec	15	2	664
Amecameca	15	2	665
Apaxco	15	2	666
Atenco	15	2	667
Atizapán	15	2	668
Atizapán de Zaragoza	15	2	669
Atlacomulco	15	2	670
Atlautla	15	2	671
Axapusco	15	2	672
Ayapango	15	2	673
Calimaya	15	2	674
Capulhuac	15	2	675
Coacalco de Berriozábal	15	2	676
Coatepec Harinas	15	2	677
Cocotitlán	15	2	678
Coyotepec	15	2	679
Cuautitlán	15	2	680
Chalco	15	2	681
Chapa de Mota	15	2	682
Chapultepec	15	2	683
Chiautla	15	2	684
Chicoloapan	15	2	685
Chiconcuac	15	2	686
Chimalhuacán	15	2	687
Donato Guerra	15	2	688
Ecatepec de Morelos	15	2	689
Ecatzingo	15	2	690
Huehuetoca	15	2	691
Hueypoxtla	15	2	692
Huixquilucan	15	2	693
Isidro Fabela	15	2	694
Ixtapaluca	15	2	695
Ixtapan de la Sal	15	2	696
Ixtapan del Oro	15	2	697
Ixtlahuaca	15	2	698
Xalatlaco	15	2	699
Jaltenco	15	2	700
Jilotepec	15	2	701
Jilotzingo	15	2	702
Jiquipilco	15	2	703
Jocotitlán	15	2	704
Joquicingo	15	2	705
Juchitepec	15	2	706
Lerma	15	2	707
Malinalco	15	2	708
Melchor Ocampo	15	2	709
Metepec	15	2	710
Mexicaltzingo	15	2	711
Morelos	15	2	712
Naucalpan de Juárez	15	2	713
Nezahualcóyotl	15	2	714
Nextlalpan	15	2	715
Nicolás Romero	15	2	716
Nopaltepec	15	2	717
Ocoyoacac	15	2	718
Ocuilan	15	2	719
El Oro	15	2	720
Otumba	15	2	721
Otzoloapan	15	2	722
Otzolotepec	15	2	723
Ozumba	15	2	724
Papalotla	15	2	725
La Paz	15	2	726
Polotitlán	15	2	727
Rayón	15	2	728
San Antonio la Isla	15	2	729
San Felipe del Progreso	15	2	730
San Martín de las Pirámides	15	2	731
San Mateo Atenco	15	2	732
San Simón de Guerrero	15	2	733
Santo Tomás	15	2	734
Soyaniquilpan de Juárez	15	2	735
Sultepec	15	2	736
Tecámac	15	2	737
Tejupilco	15	2	738
Temamatla	15	2	739
Temascalapa	15	2	740
Temascalcingo	15	2	741
Temascaltepec	15	2	742
Temoaya	15	2	743
Tenancingo	15	2	744
Tenango del Aire	15	2	745
Tenango del Valle	15	2	746
Teoloyucán	15	2	747
Teotihuacán	15	2	748
Tepetlaoxtoc	15	2	749
Tepetlixpa	15	2	750
Tepotzotlán	15	2	751
Tequixquiac	15	2	752
Texcaltitlán	15	2	753
Texcalyacac	15	2	754
Texcoco	15	2	755
Tezoyuca	15	2	756
Tianguistenco	15	2	757
Timilpan	15	2	758
Tlalmanalco	15	2	759
Tlalnepantla de Baz	15	2	760
Tlatlaya	15	2	761
Toluca	15	2	762
Tonatico	15	2	763
Tultepec	15	2	764
Tultitlán	15	2	765
Valle de Bravo	15	2	766
Villa de Allende	15	2	767
Villa del Carbón	15	2	768
Villa Guerrero	15	2	769
Villa Victoria	15	2	770
Xonacatlán	15	2	771
Zacazonapan	15	2	772
Zacualpan	15	2	773
Zinacantepec	15	2	774
Zumpahuacán	15	2	775
Zumpango	15	2	776
Cuautitlán Izcalli	15	2	777
Valle de Chalco Solidaridad	15	2	778
Luvianos	15	2	779
San José del Rincón	15	2	780
Tonanitla	15	2	781
Acuitzio	16	2	782
Aguililla	16	2	783
Álvaro Obregón	16	2	784
Angamacutiro	16	2	785
Angangueo	16	2	786
Apatzingán	16	2	787
Aporo	16	2	788
Aquila	16	2	789
Ario	16	2	790
Arteaga	16	2	791
Briseñas	16	2	792
Buenavista	16	2	793
Carácuaro	16	2	794
Coahuayana	16	2	795
Coalcomán de Vázquez Pallares	16	2	796
Coeneo	16	2	797
Contepec	16	2	798
Copándaro	16	2	799
Cotija	16	2	800
Cuitzeo	16	2	801
Charapan	16	2	802
Charo	16	2	803
Chavinda	16	2	804
Cherán	16	2	805
Chilchota	16	2	806
Chinicuila	16	2	807
Chucándiro	16	2	808
Churintzio	16	2	809
Churumuco	16	2	810
Ecuandureo	16	2	811
Epitacio Huerta	16	2	812
Erongarícuaro	16	2	813
Gabriel Zamora	16	2	814
Hidalgo	16	2	815
La Huacana	16	2	816
Huandacareo	16	2	817
Huaniqueo	16	2	818
Huetamo	16	2	819
Huiramba	16	2	820
Indaparapeo	16	2	821
Irimbo	16	2	822
Ixtlán	16	2	823
Jacona	16	2	824
Jiménez	16	2	825
Jiquilpan	16	2	826
Juárez	16	2	827
Jungapeo	16	2	828
Lagunillas	16	2	829
Madero	16	2	830
Maravatío	16	2	831
Marcos Castellanos	16	2	832
Lázaro Cárdenas	16	2	833
Morelia	16	2	834
Morelos	16	2	835
Múgica	16	2	836
Nahuatzen	16	2	837
Nocupétaro	16	2	838
Nuevo Parangaricutiro	16	2	839
Nuevo Urecho	16	2	840
Numarán	16	2	841
Ocampo	16	2	842
Pajacuarán	16	2	843
Panindícuaro	16	2	844
Parácuaro	16	2	845
Paracho	16	2	846
Pátzcuaro	16	2	847
Penjamillo	16	2	848
Peribán	16	2	849
La Piedad	16	2	850
Purépero	16	2	851
Puruándiro	16	2	852
Queréndaro	16	2	853
Quiroga	16	2	854
Cojumatlán de Régules	16	2	855
Los Reyes	16	2	856
Sahuayo	16	2	857
San Lucas	16	2	858
Santa Ana Maya	16	2	859
Salvador Escalante	16	2	860
Senguio	16	2	861
Susupuato	16	2	862
Tacámbaro	16	2	863
Tancítaro	16	2	864
Tangamandapio	16	2	865
Tangancícuaro	16	2	866
Tanhuato	16	2	867
Taretan	16	2	868
Tarímbaro	16	2	869
Tepalcatepec	16	2	870
Tingambato	16	2	871
Tingüindín	16	2	872
Tiquicheo de Nicolás Romero	16	2	873
Tlalpujahua	16	2	874
Tlazazalca	16	2	875
Tocumbo	16	2	876
Tumbiscatío	16	2	877
Turicato	16	2	878
Tuxpan	16	2	879
Tuzantla	16	2	880
Tzintzuntzan	16	2	881
Tzitzio	16	2	882
Uruapan	16	2	883
Venustiano Carranza	16	2	884
Villamar	16	2	885
Vista Hermosa	16	2	886
Yurécuaro	16	2	887
Zacapu	16	2	888
Zamora	16	2	889
Zináparo	16	2	890
Zinapécuaro	16	2	891
Ziracuaretiro	16	2	892
Zitácuaro	16	2	893
José Sixto Verduzco	16	2	894
Amacuzac	17	2	895
Atlatlahucan	17	2	896
Axochiapan	17	2	897
Ayala	17	2	898
Coatlán del Río	17	2	899
Cuautla	17	2	900
Cuernavaca	17	2	901
Emiliano Zapata	17	2	902
Huitzilac	17	2	903
Jantetelco	17	2	904
Jiutepec	17	2	905
Jojutla	17	2	906
Jonacatepec	17	2	907
Mazatepec	17	2	908
Miacatlán	17	2	909
Ocuituco	17	2	910
Puente de Ixtla	17	2	911
Temixco	17	2	912
Tepalcingo	17	2	913
Tepoztlán	17	2	914
Tetecala	17	2	915
Tetela del Volcán	17	2	916
Tlalnepantla	17	2	917
Tlaltizapán	17	2	918
Tlaquiltenango	17	2	919
Tlayacapan	17	2	920
Totolapan	17	2	921
Xochitepec	17	2	922
Yautepec	17	2	923
Yecapixtla	17	2	924
Zacatepec	17	2	925
Zacualpan	17	2	926
Temoac	17	2	927
Acaponeta	18	2	928
Ahuacatlán	18	2	929
Amatlán de Cañas	18	2	930
Compostela	18	2	931
Huajicori	18	2	932
Ixtlán del Río	18	2	933
Jala	18	2	934
Xalisco	18	2	935
Del Nayar	18	2	936
Rosamorada	18	2	937
Ruíz	18	2	938
San Blas	18	2	939
San Pedro Lagunillas	18	2	940
Santa María del Oro	18	2	941
Santiago Ixcuintla	18	2	942
Tecuala	18	2	943
Tepic	18	2	944
Tuxpan	18	2	945
La Yesca	18	2	946
Bahía de Banderas	18	2	947
Abasolo	19	2	948
Agualeguas	19	2	949
Los Aldamas	19	2	950
Allende	19	2	951
Anáhuac	19	2	952
Apodaca	19	2	953
Aramberri	19	2	954
Bustamante	19	2	955
Cadereyta Jiménez	19	2	956
Carmen	19	2	957
Cerralvo	19	2	958
Ciénega de Flores	19	2	959
China	19	2	960
Dr. Arroyo	19	2	961
Dr. Coss	19	2	962
Dr. González	19	2	963
Galeana	19	2	964
García	19	2	965
San Pedro Garza García	19	2	966
Gral. Bravo	19	2	967
Gral. Escobedo	19	2	968
Gral. Terán	19	2	969
Gral. Treviño	19	2	970
Gral. Zaragoza	19	2	971
Gral. Zuazua	19	2	972
Guadalupe	19	2	973
Los Herreras	19	2	974
Higueras	19	2	975
Hualahuises	19	2	976
Iturbide	19	2	977
Juárez	19	2	978
Lampazos de Naranjo	19	2	979
Linares	19	2	980
Marín	19	2	981
Melchor Ocampo	19	2	982
Mier y Noriega	19	2	983
Mina	19	2	984
Montemorelos	19	2	985
Monterrey	19	2	986
Parás	19	2	987
Pesquería	19	2	988
Los Ramones	19	2	989
Rayones	19	2	990
Sabinas Hidalgo	19	2	991
Salinas Victoria	19	2	992
San Nicolás de los Garza	19	2	993
Hidalgo	19	2	994
Santa Catarina	19	2	995
Santiago	19	2	996
Vallecillo	19	2	997
Villaldama	19	2	998
Abejones	20	2	999
Acatlán de Pérez Figueroa	20	2	1000
Asunción Cacalotepec	20	2	1001
Asunción Cuyotepeji	20	2	1002
Asunción Ixtaltepec	20	2	1003
Asunción Nochixtlán	20	2	1004
Asunción Ocotlán	20	2	1005
Asunción Tlacolulita	20	2	1006
Ayotzintepec	20	2	1007
El Barrio de la Soledad	20	2	1008
Calihualá	20	2	1009
Candelaria Loxicha	20	2	1010
Ciénega de Zimatlán	20	2	1011
Ciudad Ixtepec	20	2	1012
Coatecas Altas	20	2	1013
Coicoyán de las Flores	20	2	1014
La Compañía	20	2	1015
Concepción Buenavista	20	2	1016
Concepción Pápalo	20	2	1017
Constancia del Rosario	20	2	1018
Cosolapa	20	2	1019
Cosoltepec	20	2	1020
Cuilápam de Guerrero	20	2	1021
Cuyamecalco Villa de Zaragoza	20	2	1022
Chahuites	20	2	1023
Chalcatongo de Hidalgo	20	2	1024
Chiquihuitlán de Benito Juárez	20	2	1025
Heroica Ciudad de Ejutla de Crespo	20	2	1026
Eloxochitlán de Flores Magón	20	2	1027
El Espinal	20	2	1028
Tamazulápam del Espíritu Santo	20	2	1029
Fresnillo de Trujano	20	2	1030
Guadalupe Etla	20	2	1031
Guadalupe de Ramírez	20	2	1032
Guelatao de Juárez	20	2	1033
Guevea de Humboldt	20	2	1034
Mesones Hidalgo	20	2	1035
Villa Hidalgo	20	2	1036
Heroica Ciudad de Huajuapan de León	20	2	1037
Huautepec	20	2	1038
Huautla de Jiménez	20	2	1039
Ixtlán de Juárez	20	2	1040
Heroica Ciudad de Juchitán de Zaragoza	20	2	1041
Loma Bonita	20	2	1042
Magdalena Apasco	20	2	1043
Magdalena Jaltepec	20	2	1044
Santa Magdalena Jicotlán	20	2	1045
Magdalena Mixtepec	20	2	1046
Magdalena Ocotlán	20	2	1047
Magdalena Peñasco	20	2	1048
Magdalena Teitipac	20	2	1049
Magdalena Tequisistlán	20	2	1050
Magdalena Tlacotepec	20	2	1051
Magdalena Zahuatlán	20	2	1052
Mariscala de Juárez	20	2	1053
Mártires de Tacubaya	20	2	1054
Matías Romero Avendaño	20	2	1055
Mazatlán Villa de Flores	20	2	1056
Miahuatlán de Porfirio Díaz	20	2	1057
Mixistlán de la Reforma	20	2	1058
Monjas	20	2	1059
Natividad	20	2	1060
Nazareno Etla	20	2	1061
Nejapa de Madero	20	2	1062
Ixpantepec Nieves	20	2	1063
Santiago Niltepec	20	2	1064
Oaxaca de Juárez	20	2	1065
Ocotlán de Morelos	20	2	1066
La Pe	20	2	1067
Pinotepa de Don Luis	20	2	1068
Pluma Hidalgo	20	2	1069
San José del Progreso	20	2	1070
Putla Villa de Guerrero	20	2	1071
Santa Catarina Quioquitani	20	2	1072
Reforma de Pineda	20	2	1073
La Reforma	20	2	1074
Reyes Etla	20	2	1075
Rojas de Cuauhtémoc	20	2	1076
Salina Cruz	20	2	1077
San Agustín Amatengo	20	2	1078
San Agustín Atenango	20	2	1079
San Agustín Chayuco	20	2	1080
San Agustín de las Juntas	20	2	1081
San Agustín Etla	20	2	1082
San Agustín Loxicha	20	2	1083
San Agustín Tlacotepec	20	2	1084
San Agustín Yatareni	20	2	1085
San Andrés Cabecera Nueva	20	2	1086
San Andrés Dinicuiti	20	2	1087
San Andrés Huaxpaltepec	20	2	1088
San Andrés Huayápam	20	2	1089
San Andrés Ixtlahuaca	20	2	1090
San Andrés Lagunas	20	2	1091
San Andrés Nuxiño	20	2	1092
San Andrés Paxtlán	20	2	1093
San Andrés Sinaxtla	20	2	1094
San Andrés Solaga	20	2	1095
San Andrés Teotilálpam	20	2	1096
San Andrés Tepetlapa	20	2	1097
San Andrés Yaá	20	2	1098
San Andrés Zabache	20	2	1099
San Andrés Zautla	20	2	1100
San Antonino Castillo Velasco	20	2	1101
San Antonino el Alto	20	2	1102
San Antonino Monte Verde	20	2	1103
San Antonio Acutla	20	2	1104
San Antonio de la Cal	20	2	1105
San Antonio Huitepec	20	2	1106
San Antonio Nanahuatípam	20	2	1107
San Antonio Sinicahua	20	2	1108
San Antonio Tepetlapa	20	2	1109
San Baltazar Chichicápam	20	2	1110
San Baltazar Loxicha	20	2	1111
San Baltazar Yatzachi el Bajo	20	2	1112
San Bartolo Coyotepec	20	2	1113
San Bartolomé Ayautla	20	2	1114
San Bartolomé Loxicha	20	2	1115
San Bartolomé Quialana	20	2	1116
San Bartolomé Yucuañe	20	2	1117
San Bartolomé Zoogocho	20	2	1118
San Bartolo Soyaltepec	20	2	1119
San Bartolo Yautepec	20	2	1120
San Bernardo Mixtepec	20	2	1121
San Blas Atempa	20	2	1122
San Carlos Yautepec	20	2	1123
San Cristóbal Amatlán	20	2	1124
San Cristóbal Amoltepec	20	2	1125
San Cristóbal Lachirioag	20	2	1126
San Cristóbal Suchixtlahuaca	20	2	1127
San Dionisio del Mar	20	2	1128
San Dionisio Ocotepec	20	2	1129
San Dionisio Ocotlán	20	2	1130
San Esteban Atatlahuca	20	2	1131
San Felipe Jalapa de Díaz	20	2	1132
San Felipe Tejalápam	20	2	1133
San Felipe Usila	20	2	1134
San Francisco Cahuacuá	20	2	1135
San Francisco Cajonos	20	2	1136
San Francisco Chapulapa	20	2	1137
San Francisco Chindúa	20	2	1138
San Francisco del Mar	20	2	1139
San Francisco Huehuetlán	20	2	1140
San Francisco Ixhuatán	20	2	1141
San Francisco Jaltepetongo	20	2	1142
San Francisco Lachigoló	20	2	1143
San Francisco Logueche	20	2	1144
San Francisco Nuxaño	20	2	1145
San Francisco Ozolotepec	20	2	1146
San Francisco Sola	20	2	1147
San Francisco Telixtlahuaca	20	2	1148
San Francisco Teopan	20	2	1149
San Francisco Tlapancingo	20	2	1150
San Gabriel Mixtepec	20	2	1151
San Ildefonso Amatlán	20	2	1152
San Ildefonso Sola	20	2	1153
San Ildefonso Villa Alta	20	2	1154
San Jacinto Amilpas	20	2	1155
San Jacinto Tlacotepec	20	2	1156
San Jerónimo Coatlán	20	2	1157
San Jerónimo Silacayoapilla	20	2	1158
San Jerónimo Sosola	20	2	1159
San Jerónimo Taviche	20	2	1160
San Jerónimo Tecóatl	20	2	1161
San Jorge Nuchita	20	2	1162
San José Ayuquila	20	2	1163
San José Chiltepec	20	2	1164
San José del Peñasco	20	2	1165
San José Estancia Grande	20	2	1166
San José Independencia	20	2	1167
San José Lachiguiri	20	2	1168
San José Tenango	20	2	1169
San Juan Achiutla	20	2	1170
San Juan Atepec	20	2	1171
Ánimas Trujano	20	2	1172
San Juan Bautista Atatlahuca	20	2	1173
San Juan Bautista Coixtlahuaca	20	2	1174
San Juan Bautista Cuicatlán	20	2	1175
San Juan Bautista Guelache	20	2	1176
San Juan Bautista Jayacatlán	20	2	1177
San Juan Bautista Lo de Soto	20	2	1178
San Juan Bautista Suchitepec	20	2	1179
San Juan Bautista Tlacoatzintepec	20	2	1180
San Juan Bautista Tlachichilco	20	2	1181
San Juan Bautista Tuxtepec	20	2	1182
San Juan Cacahuatepec	20	2	1183
San Juan Cieneguilla	20	2	1184
San Juan Coatzóspam	20	2	1185
San Juan Colorado	20	2	1186
San Juan Comaltepec	20	2	1187
San Juan Cotzocón	20	2	1188
San Juan Chicomezúchil	20	2	1189
San Juan Chilateca	20	2	1190
San Juan del Estado	20	2	1191
San Juan del Río	20	2	1192
San Juan Diuxi	20	2	1193
San Juan Evangelista Analco	20	2	1194
San Juan Guelavía	20	2	1195
San Juan Guichicovi	20	2	1196
San Juan Ihualtepec	20	2	1197
San Juan Juquila Mixes	20	2	1198
San Juan Juquila Vijanos	20	2	1199
San Juan Lachao	20	2	1200
San Juan Lachigalla	20	2	1201
San Juan Lajarcia	20	2	1202
San Juan Lalana	20	2	1203
San Juan de los Cués	20	2	1204
San Juan Mazatlán	20	2	1205
San Juan Mixtepec -Dto. 08 -	20	2	1206
San Juan Mixtepec -Dto. 26 -	20	2	1207
San Juan Ñumí	20	2	1208
San Juan Ozolotepec	20	2	1209
San Juan Petlapa	20	2	1210
San Juan Quiahije	20	2	1211
San Juan Quiotepec	20	2	1212
San Juan Sayultepec	20	2	1213
San Juan Tabaá	20	2	1214
San Juan Tamazola	20	2	1215
San Juan Teita	20	2	1216
San Juan Teitipac	20	2	1217
San Juan Tepeuxila	20	2	1218
San Juan Teposcolula	20	2	1219
San Juan Yaeé	20	2	1220
San Juan Yatzona	20	2	1221
San Juan Yucuita	20	2	1222
San Lorenzo	20	2	1223
San Lorenzo Albarradas	20	2	1224
San Lorenzo Cacaotepec	20	2	1225
San Lorenzo Cuaunecuiltitla	20	2	1226
San Lorenzo Texmelúcan	20	2	1227
San Lorenzo Victoria	20	2	1228
San Lucas Camotlán	20	2	1229
San Lucas Ojitlán	20	2	1230
San Lucas Quiaviní	20	2	1231
San Lucas Zoquiápam	20	2	1232
San Luis Amatlán	20	2	1233
San Marcial Ozolotepec	20	2	1234
San Marcos Arteaga	20	2	1235
San Martín de los Cansecos	20	2	1236
San Martín Huamelúlpam	20	2	1237
San Martín Itunyoso	20	2	1238
San Martín Lachilá	20	2	1239
San Martín Peras	20	2	1240
San Martín Tilcajete	20	2	1241
San Martín Toxpalan	20	2	1242
San Martín Zacatepec	20	2	1243
San Mateo Cajonos	20	2	1244
Capulálpam de Méndez	20	2	1245
San Mateo del Mar	20	2	1246
San Mateo Yoloxochitlán	20	2	1247
San Mateo Etlatongo	20	2	1248
San Mateo Nejápam	20	2	1249
San Mateo Peñasco	20	2	1250
San Mateo Piñas	20	2	1251
San Mateo Río Hondo	20	2	1252
San Mateo Sindihui	20	2	1253
San Mateo Tlapiltepec	20	2	1254
San Melchor Betaza	20	2	1255
San Miguel Achiutla	20	2	1256
San Miguel Ahuehuetitlán	20	2	1257
San Miguel Aloápam	20	2	1258
San Miguel Amatitlán	20	2	1259
San Miguel Amatlán	20	2	1260
San Miguel Coatlán	20	2	1261
San Miguel Chicahua	20	2	1262
San Miguel Chimalapa	20	2	1263
San Miguel del Puerto	20	2	1264
San Miguel del Río	20	2	1265
San Miguel Ejutla	20	2	1266
San Miguel el Grande	20	2	1267
San Miguel Huautla	20	2	1268
San Miguel Mixtepec	20	2	1269
San Miguel Panixtlahuaca	20	2	1270
San Miguel Peras	20	2	1271
San Miguel Piedras	20	2	1272
San Miguel Quetzaltepec	20	2	1273
San Miguel Santa Flor	20	2	1274
Villa Sola de Vega	20	2	1275
San Miguel Soyaltepec	20	2	1276
San Miguel Suchixtepec	20	2	1277
Villa Talea de Castro	20	2	1278
San Miguel Tecomatlán	20	2	1279
San Miguel Tenango	20	2	1280
San Miguel Tequixtepec	20	2	1281
San Miguel Tilquiápam	20	2	1282
San Miguel Tlacamama	20	2	1283
San Miguel Tlacotepec	20	2	1284
San Miguel Tulancingo	20	2	1285
San Miguel Yotao	20	2	1286
San Nicolás	20	2	1287
San Nicolás Hidalgo	20	2	1288
San Pablo Coatlán	20	2	1289
San Pablo Cuatro Venados	20	2	1290
San Pablo Etla	20	2	1291
San Pablo Huitzo	20	2	1292
San Pablo Huixtepec	20	2	1293
San Pablo Macuiltianguis	20	2	1294
San Pablo Tijaltepec	20	2	1295
San Pablo Villa de Mitla	20	2	1296
San Pablo Yaganiza	20	2	1297
San Pedro Amuzgos	20	2	1298
San Pedro Apóstol	20	2	1299
San Pedro Atoyac	20	2	1300
San Pedro Cajonos	20	2	1301
San Pedro Coxcaltepec Cántaros	20	2	1302
San Pedro Comitancillo	20	2	1303
San Pedro el Alto	20	2	1304
San Pedro Huamelula	20	2	1305
San Pedro Huilotepec	20	2	1306
San Pedro Ixcatlán	20	2	1307
San Pedro Ixtlahuaca	20	2	1308
San Pedro Jaltepetongo	20	2	1309
San Pedro Jicayán	20	2	1310
San Pedro Jocotipac	20	2	1311
San Pedro Juchatengo	20	2	1312
San Pedro Mártir	20	2	1313
San Pedro Mártir Quiechapa	20	2	1314
San Pedro Mártir Yucuxaco	20	2	1315
San Pedro Mixtepec -Dto. 22 -	20	2	1316
San Pedro Mixtepec -Dto. 26 -	20	2	1317
San Pedro Molinos	20	2	1318
San Pedro Nopala	20	2	1319
San Pedro Ocopetatillo	20	2	1320
San Pedro Ocotepec	20	2	1321
San Pedro Pochutla	20	2	1322
San Pedro Quiatoni	20	2	1323
San Pedro Sochiápam	20	2	1324
San Pedro Tapanatepec	20	2	1325
San Pedro Taviche	20	2	1326
San Pedro Teozacoalco	20	2	1327
San Pedro Teutila	20	2	1328
San Pedro Tidaá	20	2	1329
San Pedro Topiltepec	20	2	1330
San Pedro Totolapa	20	2	1331
Villa de Tututepec de Melchor Ocampo	20	2	1332
San Pedro Yaneri	20	2	1333
San Pedro Yólox	20	2	1334
San Pedro y San Pablo Ayutla	20	2	1335
Villa de Etla	20	2	1336
San Pedro y San Pablo Teposcolula	20	2	1337
San Pedro y San Pablo Tequixtepec	20	2	1338
San Pedro Yucunama	20	2	1339
San Raymundo Jalpan	20	2	1340
San Sebastián Abasolo	20	2	1341
San Sebastián Coatlán	20	2	1342
San Sebastián Ixcapa	20	2	1343
San Sebastián Nicananduta	20	2	1344
San Sebastián Río Hondo	20	2	1345
San Sebastián Tecomaxtlahuaca	20	2	1346
San Sebastián Teitipac	20	2	1347
San Sebastián Tutla	20	2	1348
San Simón Almolongas	20	2	1349
San Simón Zahuatlán	20	2	1350
Santa Ana	20	2	1351
Santa Ana Ateixtlahuaca	20	2	1352
Santa Ana Cuauhtémoc	20	2	1353
Santa Ana del Valle	20	2	1354
Santa Ana Tavela	20	2	1355
Santa Ana Tlapacoyan	20	2	1356
Santa Ana Yareni	20	2	1357
Santa Ana Zegache	20	2	1358
Santa Catalina Quierí	20	2	1359
Santa Catarina Cuixtla	20	2	1360
Santa Catarina Ixtepeji	20	2	1361
Santa Catarina Juquila	20	2	1362
Santa Catarina Lachatao	20	2	1363
Santa Catarina Loxicha	20	2	1364
Santa Catarina Mechoacán	20	2	1365
Santa Catarina Minas	20	2	1366
Santa Catarina Quiané	20	2	1367
Santa Catarina Tayata	20	2	1368
Santa Catarina Ticuá	20	2	1369
Santa Catarina Yosonotú	20	2	1370
Santa Catarina Zapoquila	20	2	1371
Santa Cruz Acatepec	20	2	1372
Santa Cruz Amilpas	20	2	1373
Santa Cruz de Bravo	20	2	1374
Santa Cruz Itundujia	20	2	1375
Santa Cruz Mixtepec	20	2	1376
Santa Cruz Nundaco	20	2	1377
Santa Cruz Papalutla	20	2	1378
Santa Cruz Tacache de Mina	20	2	1379
Santa Cruz Tacahua	20	2	1380
Santa Cruz Tayata	20	2	1381
Santa Cruz Xitla	20	2	1382
Santa Cruz Xoxocotlán	20	2	1383
Santa Cruz Zenzontepec	20	2	1384
Santa Gertrudis	20	2	1385
Santa Inés del Monte	20	2	1386
Santa Inés Yatzeche	20	2	1387
Santa Lucía del Camino	20	2	1388
Santa Lucía Miahuatlán	20	2	1389
Santa Lucía Monteverde	20	2	1390
Santa Lucía Ocotlán	20	2	1391
Santa María Alotepec	20	2	1392
Santa María Apazco	20	2	1393
Santa María la Asunción	20	2	1394
Heroica Ciudad de Tlaxiaco	20	2	1395
Ayoquezco de Aldama	20	2	1396
Santa María Atzompa	20	2	1397
Santa María Camotlán	20	2	1398
Santa María Colotepec	20	2	1399
Santa María Cortijo	20	2	1400
Santa María Coyotepec	20	2	1401
Santa María Chachoápam	20	2	1402
Villa de Chilapa de Díaz	20	2	1403
Santa María Chilchotla	20	2	1404
Santa María Chimalapa	20	2	1405
Santa María del Rosario	20	2	1406
Santa María del Tule	20	2	1407
Santa María Ecatepec	20	2	1408
Santa María Guelacé	20	2	1409
Santa María Guienagati	20	2	1410
Santa María Huatulco	20	2	1411
Santa María Huazolotitlán	20	2	1412
Santa María Ipalapa	20	2	1413
Santa María Ixcatlán	20	2	1414
Santa María Jacatepec	20	2	1415
Santa María Jalapa del Marqués	20	2	1416
Santa María Jaltianguis	20	2	1417
Santa María Lachixío	20	2	1418
Santa María Mixtequilla	20	2	1419
Santa María Nativitas	20	2	1420
Santa María Nduayaco	20	2	1421
Santa María Ozolotepec	20	2	1422
Santa María Pápalo	20	2	1423
Santa María Peñoles	20	2	1424
Santa María Petapa	20	2	1425
Santa María Quiegolani	20	2	1426
Santa María Sola	20	2	1427
Santa María Tataltepec	20	2	1428
Santa María Tecomavaca	20	2	1429
Santa María Temaxcalapa	20	2	1430
Santa María Temaxcaltepec	20	2	1431
Santa María Teopoxco	20	2	1432
Santa María Tepantlali	20	2	1433
Santa María Texcatitlán	20	2	1434
Santa María Tlahuitoltepec	20	2	1435
Santa María Tlalixtac	20	2	1436
Santa María Tonameca	20	2	1437
Santa María Totolapilla	20	2	1438
Santa María Xadani	20	2	1439
Santa María Yalina	20	2	1440
Santa María Yavesía	20	2	1441
Santa María Yolotepec	20	2	1442
Santa María Yosoyúa	20	2	1443
Santa María Yucuhiti	20	2	1444
Santa María Zacatepec	20	2	1445
Santa María Zaniza	20	2	1446
Santa María Zoquitlán	20	2	1447
Santiago Amoltepec	20	2	1448
Santiago Apoala	20	2	1449
Santiago Apóstol	20	2	1450
Santiago Astata	20	2	1451
Santiago Atitlán	20	2	1452
Santiago Ayuquililla	20	2	1453
Santiago Cacaloxtepec	20	2	1454
Santiago Camotlán	20	2	1455
Santiago Comaltepec	20	2	1456
Santiago Chazumba	20	2	1457
Santiago Choápam	20	2	1458
Santiago del Río	20	2	1459
Santiago Huajolotitlán	20	2	1460
Santiago Huauclilla	20	2	1461
Santiago Ihuitlán Plumas	20	2	1462
Santiago Ixcuintepec	20	2	1463
Santiago Ixtayutla	20	2	1464
Santiago Jamiltepec	20	2	1465
Santiago Jocotepec	20	2	1466
Santiago Juxtlahuaca	20	2	1467
Santiago Lachiguiri	20	2	1468
Santiago Lalopa	20	2	1469
Santiago Laollaga	20	2	1470
Santiago Laxopa	20	2	1471
Santiago Llano Grande	20	2	1472
Santiago Matatlán	20	2	1473
Santiago Miltepec	20	2	1474
Santiago Minas	20	2	1475
Santiago Nacaltepec	20	2	1476
Santiago Nejapilla	20	2	1477
Santiago Nundiche	20	2	1478
Santiago Nuyoó	20	2	1479
Santiago Pinotepa Nacional	20	2	1480
Santiago Suchilquitongo	20	2	1481
Santiago Tamazola	20	2	1482
Santiago Tapextla	20	2	1483
Villa Tejúpam de la Unión	20	2	1484
Santiago Tenango	20	2	1485
Santiago Tepetlapa	20	2	1486
Santiago Tetepec	20	2	1487
Santiago Texcalcingo	20	2	1488
Santiago Textitlán	20	2	1489
Santiago Tilantongo	20	2	1490
Santiago Tillo	20	2	1491
Santiago Tlazoyaltepec	20	2	1492
Santiago Xanica	20	2	1493
Santiago Xiacuí	20	2	1494
Santiago Yaitepec	20	2	1495
Santiago Yaveo	20	2	1496
Santiago Yolomécatl	20	2	1497
Santiago Yosondúa	20	2	1498
Santiago Yucuyachi	20	2	1499
Santiago Zacatepec	20	2	1500
Santiago Zoochila	20	2	1501
Nuevo Zoquiápam	20	2	1502
Santo Domingo Ingenio	20	2	1503
Santo Domingo Albarradas	20	2	1504
Santo Domingo Armenta	20	2	1505
Santo Domingo Chihuitán	20	2	1506
Santo Domingo de Morelos	20	2	1507
Santo Domingo Ixcatlán	20	2	1508
Santo Domingo Nuxaá	20	2	1509
Santo Domingo Ozolotepec	20	2	1510
Santo Domingo Petapa	20	2	1511
Santo Domingo Roayaga	20	2	1512
Santo Domingo Tehuantepec	20	2	1513
Santo Domingo Teojomulco	20	2	1514
Santo Domingo Tepuxtepec	20	2	1515
Santo Domingo Tlatayápam	20	2	1516
Santo Domingo Tomaltepec	20	2	1517
Santo Domingo Tonalá	20	2	1518
Santo Domingo Tonaltepec	20	2	1519
Santo Domingo Xagacía	20	2	1520
Santo Domingo Yanhuitlán	20	2	1521
Santo Domingo Yodohino	20	2	1522
Santo Domingo Zanatepec	20	2	1523
Santos Reyes Nopala	20	2	1524
Santos Reyes Pápalo	20	2	1525
Santos Reyes Tepejillo	20	2	1526
Santos Reyes Yucuná	20	2	1527
Santo Tomás Jalieza	20	2	1528
Santo Tomás Mazaltepec	20	2	1529
Santo Tomás Ocotepec	20	2	1530
Santo Tomás Tamazulapan	20	2	1531
San Vicente Coatlán	20	2	1532
San Vicente Lachixío	20	2	1533
San Vicente Nuñú	20	2	1534
Silacayoápam	20	2	1535
Sitio de Xitlapehua	20	2	1536
Soledad Etla	20	2	1537
Villa de Tamazulápam del Progreso	20	2	1538
Tanetze de Zaragoza	20	2	1539
Taniche	20	2	1540
Tataltepec de Valdés	20	2	1541
Teococuilco de Marcos Pérez	20	2	1542
Teotitlán de Flores Magón	20	2	1543
Teotitlán del Valle	20	2	1544
Teotongo	20	2	1545
Tepelmeme Villa de Morelos	20	2	1546
Tezoatlán de Segura y Luna	20	2	1547
San Jerónimo Tlacochahuaya	20	2	1548
Tlacolula de Matamoros	20	2	1549
Tlacotepec Plumas	20	2	1550
Tlalixtac de Cabrera	20	2	1551
Totontepec Villa de Morelos	20	2	1552
Trinidad Zaachila	20	2	1553
La Trinidad Vista Hermosa	20	2	1554
Unión Hidalgo	20	2	1555
Valerio Trujano	20	2	1556
San Juan Bautista Valle Nacional	20	2	1557
Villa Díaz Ordaz	20	2	1558
Yaxe	20	2	1559
Magdalena Yodocono de Porfirio Díaz	20	2	1560
Yogana	20	2	1561
Yutanduchi de Guerrero	20	2	1562
Villa de Zaachila	20	2	1563
Zapotitlán del Río	20	2	1564
Zapotitlán Lagunas	20	2	1565
Zapotitlán Palmas	20	2	1566
Santa Inés de Zaragoza	20	2	1567
Zimatlán de Álvarez	20	2	1568
Acajete	21	2	1569
Acateno	21	2	1570
Acatlán	21	2	1571
Acatzingo	21	2	1572
Acteopan	21	2	1573
Ahuacatlán	21	2	1574
Ahuatlán	21	2	1575
Ahuazotepec	21	2	1576
Ahuehuetitla	21	2	1577
Ajalpan	21	2	1578
Albino Zertuche	21	2	1579
Aljojuca	21	2	1580
Altepexi	21	2	1581
Amixtlán	21	2	1582
Amozoc	21	2	1583
Aquixtla	21	2	1584
Atempan	21	2	1585
Atexcal	21	2	1586
Atlixco	21	2	1587
Atoyatempan	21	2	1588
Atzala	21	2	1589
Atzitzihuacán	21	2	1590
Atzitzintla	21	2	1591
Axutla	21	2	1592
Ayotoxco de Guerrero	21	2	1593
Calpan	21	2	1594
Caltepec	21	2	1595
Camocuautla	21	2	1596
Caxhuacan	21	2	1597
Coatepec	21	2	1598
Coatzingo	21	2	1599
Cohetzala	21	2	1600
Cohuecan	21	2	1601
Coronango	21	2	1602
Coxcatlán	21	2	1603
Coyomeapan	21	2	1604
Coyotepec	21	2	1605
Cuapiaxtla de Madero	21	2	1606
Cuautempan	21	2	1607
Cuautinchán	21	2	1608
Cuautlancingo	21	2	1609
Cuayuca de Andrade	21	2	1610
Cuetzalan del Progreso	21	2	1611
Cuyoaco	21	2	1612
Chalchicomula de Sesma	21	2	1613
Chapulco	21	2	1614
Chiautla	21	2	1615
Chiautzingo	21	2	1616
Chiconcuautla	21	2	1617
Chichiquila	21	2	1618
Chietla	21	2	1619
Chigmecatitlán	21	2	1620
Chignahuapan	21	2	1621
Chignautla	21	2	1622
Chila	21	2	1623
Chila de la Sal	21	2	1624
Honey	21	2	1625
Chilchotla	21	2	1626
Chinantla	21	2	1627
Domingo Arenas	21	2	1628
Eloxochitlán	21	2	1629
Epatlán	21	2	1630
Esperanza	21	2	1631
Francisco Z. Mena	21	2	1632
General Felipe Ángeles	21	2	1633
Guadalupe	21	2	1634
Guadalupe Victoria	21	2	1635
Hermenegildo Galeana	21	2	1636
Huaquechula	21	2	1637
Huatlatlauca	21	2	1638
Huauchinango	21	2	1639
Huehuetla	21	2	1640
Huehuetlán el Chico	21	2	1641
Huejotzingo	21	2	1642
Hueyapan	21	2	1643
Hueytamalco	21	2	1644
Hueytlalpan	21	2	1645
Huitzilan de Serdán	21	2	1646
Huitziltepec	21	2	1647
Atlequizayan	21	2	1648
Ixcamilpa de Guerrero	21	2	1649
Ixcaquixtla	21	2	1650
Ixtacamaxtitlán	21	2	1651
Ixtepec	21	2	1652
Izúcar de Matamoros	21	2	1653
Jalpan	21	2	1654
Jolalpan	21	2	1655
Jonotla	21	2	1656
Jopala	21	2	1657
Juan C. Bonilla	21	2	1658
Juan Galindo	21	2	1659
Juan N. Méndez	21	2	1660
Lafragua	21	2	1661
Libres	21	2	1662
La Magdalena Tlatlauquitepec	21	2	1663
Mazapiltepec de Juárez	21	2	1664
Mixtla	21	2	1665
Molcaxac	21	2	1666
Cañada Morelos	21	2	1667
Naupan	21	2	1668
Nauzontla	21	2	1669
Nealtican	21	2	1670
Nicolás Bravo	21	2	1671
Nopalucan	21	2	1672
Ocotepec	21	2	1673
Ocoyucan	21	2	1674
Olintla	21	2	1675
Oriental	21	2	1676
Pahuatlán	21	2	1677
Palmar de Bravo	21	2	1678
Pantepec	21	2	1679
Petlalcingo	21	2	1680
Piaxtla	21	2	1681
Puebla	21	2	1682
Quecholac	21	2	1683
Quimixtlán	21	2	1684
Rafael Lara Grajales	21	2	1685
Los Reyes de Juárez	21	2	1686
San Andrés Cholula	21	2	1687
San Antonio Cañada	21	2	1688
San Diego la Mesa Tochimiltzingo	21	2	1689
San Felipe Teotlalcingo	21	2	1690
San Felipe Tepatlán	21	2	1691
San Gabriel Chilac	21	2	1692
San Gregorio Atzompa	21	2	1693
San Jerónimo Tecuanipan	21	2	1694
San Jerónimo Xayacatlán	21	2	1695
San José Chiapa	21	2	1696
San José Miahuatlán	21	2	1697
San Juan Atenco	21	2	1698
San Juan Atzompa	21	2	1699
San Martín Texmelucan	21	2	1700
San Martín Totoltepec	21	2	1701
San Matías Tlalancaleca	21	2	1702
San Miguel Ixitlán	21	2	1703
San Miguel Xoxtla	21	2	1704
San Nicolás Buenos Aires	21	2	1705
San Nicolás de los Ranchos	21	2	1706
San Pablo Anicano	21	2	1707
San Pedro Cholula	21	2	1708
San Pedro Yeloixtlahuaca	21	2	1709
San Salvador el Seco	21	2	1710
San Salvador el Verde	21	2	1711
San Salvador Huixcolotla	21	2	1712
San Sebastián Tlacotepec	21	2	1713
Santa Catarina Tlaltempan	21	2	1714
Santa Inés Ahuatempan	21	2	1715
Santa Isabel Cholula	21	2	1716
Santiago Miahuatlán	21	2	1717
Huehuetlán el Grande	21	2	1718
Santo Tomás Hueyotlipan	21	2	1719
Soltepec	21	2	1720
Tecali de Herrera	21	2	1721
Tecamachalco	21	2	1722
Tecomatlán	21	2	1723
Tehuacán	21	2	1724
Tehuitzingo	21	2	1725
Tenampulco	21	2	1726
Teopantlán	21	2	1727
Teotlalco	21	2	1728
Tepanco de López	21	2	1729
Tepango de Rodríguez	21	2	1730
Tepatlaxco de Hidalgo	21	2	1731
Tepeaca	21	2	1732
Tepemaxalco	21	2	1733
Tepeojuma	21	2	1734
Tepetzintla	21	2	1735
Tepexco	21	2	1736
Tepexi de Rodríguez	21	2	1737
Tepeyahualco	21	2	1738
Tepeyahualco de Cuauhtémoc	21	2	1739
Tetela de Ocampo	21	2	1740
Teteles de Avila Castillo	21	2	1741
Teziutlán	21	2	1742
Tianguismanalco	21	2	1743
Tilapa	21	2	1744
Tlacotepec de Benito Juárez	21	2	1745
Tlacuilotepec	21	2	1746
Tlachichuca	21	2	1747
Tlahuapan	21	2	1748
Tlaltenango	21	2	1749
Tlanepantla	21	2	1750
Tlaola	21	2	1751
Tlapacoya	21	2	1752
Tlapanalá	21	2	1753
Tlatlauquitepec	21	2	1754
Tlaxco	21	2	1755
Tochimilco	21	2	1756
Tochtepec	21	2	1757
Totoltepec de Guerrero	21	2	1758
Tulcingo	21	2	1759
Tuzamapan de Galeana	21	2	1760
Tzicatlacoyan	21	2	1761
Venustiano Carranza	21	2	1762
Vicente Guerrero	21	2	1763
Xayacatlán de Bravo	21	2	1764
Xicotepec	21	2	1765
Xicotlán	21	2	1766
Xiutetelco	21	2	1767
Xochiapulco	21	2	1768
Xochiltepec	21	2	1769
Xochitlán de Vicente Suárez	21	2	1770
Xochitlán Todos Santos	21	2	1771
Yaonáhuac	21	2	1772
Yehualtepec	21	2	1773
Zacapala	21	2	1774
Zacapoaxtla	21	2	1775
Zacatlán	21	2	1776
Zapotitlán	21	2	1777
Zapotitlán de Méndez	21	2	1778
Zaragoza	21	2	1779
Zautla	21	2	1780
Zihuateutla	21	2	1781
Zinacatepec	21	2	1782
Zongozotla	21	2	1783
Zoquiapan	21	2	1784
Zoquitlán	21	2	1785
Amealco de Bonfil	22	2	1786
Pinal de Amoles	22	2	1787
Arroyo Seco	22	2	1788
Cadereyta de Montes	22	2	1789
Colón	22	2	1790
Corregidora	22	2	1791
Ezequiel Montes	22	2	1792
Huimilpan	22	2	1793
Jalpan de Serra	22	2	1794
Landa de Matamoros	22	2	1795
El Marqués	22	2	1796
Pedro Escobedo	22	2	1797
Peñamiller	22	2	1798
Querétaro	22	2	1799
San Joaquín	22	2	1800
San Juan del Río	22	2	1801
Tequisquiapan	22	2	1802
Tolimán	22	2	1803
Cozumel	23	2	1804
Felipe Carrillo Puerto	23	2	1805
Isla Mujeres	23	2	1806
Othón P. Blanco	23	2	1807
Benito Juárez	23	2	1808
José María Morelos	23	2	1809
Lázaro Cárdenas	23	2	1810
Solidaridad	23	2	1811
Tulum	23	2	1812
Ahualulco	24	2	1813
Alaquines	24	2	1814
Aquismón	24	2	1815
Armadillo de los Infante	24	2	1816
Cárdenas	24	2	1817
Catorce	24	2	1818
Cedral	24	2	1819
Cerritos	24	2	1820
Cerro de San Pedro	24	2	1821
Ciudad del Maíz	24	2	1822
Ciudad Fernández	24	2	1823
Tancanhuitz	24	2	1824
Ciudad Valles	24	2	1825
Coxcatlán	24	2	1826
Charcas	24	2	1827
Ebano	24	2	1828
Guadalcázar	24	2	1829
Huehuetlán	24	2	1830
Lagunillas	24	2	1831
Matehuala	24	2	1832
Mexquitic de Carmona	24	2	1833
Moctezuma	24	2	1834
Rayón	24	2	1835
Rioverde	24	2	1836
Salinas	24	2	1837
San Antonio	24	2	1838
San Ciro de Acosta	24	2	1839
San Luis Potosí	24	2	1840
San Martín Chalchicuautla	24	2	1841
San Nicolás Tolentino	24	2	1842
Santa Catarina	24	2	1843
Santa María del Río	24	2	1844
Santo Domingo	24	2	1845
San Vicente Tancuayalab	24	2	1846
Soledad de Graciano Sánchez	24	2	1847
Tamasopo	24	2	1848
Tamazunchale	24	2	1849
Tampacán	24	2	1850
Tampamolón Corona	24	2	1851
Tamuín	24	2	1852
Tanlajás	24	2	1853
Tanquián de Escobedo	24	2	1854
Tierra Nueva	24	2	1855
Vanegas	24	2	1856
Venado	24	2	1857
Villa de Arriaga	24	2	1858
Villa de Guadalupe	24	2	1859
Villa de la Paz	24	2	1860
Villa de Ramos	24	2	1861
Villa de Reyes	24	2	1862
Villa Hidalgo	24	2	1863
Villa Juárez	24	2	1864
Axtla de Terrazas	24	2	1865
Xilitla	24	2	1866
Zaragoza	24	2	1867
Villa de Arista	24	2	1868
Matlapa	24	2	1869
El Naranjo	24	2	1870
Ahome	25	2	1871
Angostura	25	2	1872
Badiraguato	25	2	1873
Concordia	25	2	1874
Cosalá	25	2	1875
Culiacán	25	2	1876
Choix	25	2	1877
Elota	25	2	1878
Escuinapa	25	2	1879
El Fuerte	25	2	1880
Guasave	25	2	1881
Mazatlán	25	2	1882
Mocorito	25	2	1883
Rosario	25	2	1884
Salvador Alvarado	25	2	1885
San Ignacio	25	2	1886
Sinaloa	25	2	1887
Navolato	25	2	1888
Aconchi	26	2	1889
Agua Prieta	26	2	1890
Alamos	26	2	1891
Altar	26	2	1892
Arivechi	26	2	1893
Arizpe	26	2	1894
Atil	26	2	1895
Bacadéhuachi	26	2	1896
Bacanora	26	2	1897
Bacerac	26	2	1898
Bacoachi	26	2	1899
Bácum	26	2	1900
Banámichi	26	2	1901
Baviácora	26	2	1902
Bavispe	26	2	1903
Benjamín Hill	26	2	1904
Caborca	26	2	1905
Cajeme	26	2	1906
Cananea	26	2	1907
Carbó	26	2	1908
La Colorada	26	2	1909
Cucurpe	26	2	1910
Cumpas	26	2	1911
Divisaderos	26	2	1912
Empalme	26	2	1913
Etchojoa	26	2	1914
Fronteras	26	2	1915
Granados	26	2	1916
Guaymas	26	2	1917
Hermosillo	26	2	1918
Huachinera	26	2	1919
Huásabas	26	2	1920
Huatabampo	26	2	1921
Huépac	26	2	1922
Imuris	26	2	1923
Magdalena	26	2	1924
Mazatán	26	2	1925
Moctezuma	26	2	1926
Naco	26	2	1927
Nácori Chico	26	2	1928
Nacozari de García	26	2	1929
Navojoa	26	2	1930
Nogales	26	2	1931
Onavas	26	2	1932
Opodepe	26	2	1933
Oquitoa	26	2	1934
Pitiquito	26	2	1935
Puerto Peñasco	26	2	1936
Quiriego	26	2	1937
Rayón	26	2	1938
Rosario	26	2	1939
Sahuaripa	26	2	1940
San Felipe de Jesús	26	2	1941
San Javier	26	2	1942
San Luis Río Colorado	26	2	1943
San Miguel de Horcasitas	26	2	1944
San Pedro de la Cueva	26	2	1945
Santa Ana	26	2	1946
Santa Cruz	26	2	1947
Sáric	26	2	1948
Soyopa	26	2	1949
Suaqui Grande	26	2	1950
Tepache	26	2	1951
Trincheras	26	2	1952
Tubutama	26	2	1953
Ures	26	2	1954
Villa Hidalgo	26	2	1955
Villa Pesqueira	26	2	1956
Yécora	26	2	1957
General Plutarco Elías Calles	26	2	1958
Benito Juárez	26	2	1959
San Ignacio Río Muerto	26	2	1960
Balancán	27	2	1961
Cárdenas	27	2	1962
Centla	27	2	1963
Centro	27	2	1964
Comalcalco	27	2	1965
Cunduacán	27	2	1966
Emiliano Zapata	27	2	1967
Huimanguillo	27	2	1968
Jalapa	27	2	1969
Jalpa de Méndez	27	2	1970
Jonuta	27	2	1971
Macuspana	27	2	1972
Nacajuca	27	2	1973
Paraíso	27	2	1974
Tacotalpa	27	2	1975
Teapa	27	2	1976
Tenosique	27	2	1977
Abasolo	28	2	1978
Aldama	28	2	1979
Altamira	28	2	1980
Antiguo Morelos	28	2	1981
Burgos	28	2	1982
Bustamante	28	2	1983
Camargo	28	2	1984
Casas	28	2	1985
Ciudad Madero	28	2	1986
Cruillas	28	2	1987
Gómez Farías	28	2	1988
González	28	2	1989
Güémez	28	2	1990
Guerrero	28	2	1991
Gustavo Díaz Ordaz	28	2	1992
Hidalgo	28	2	1993
Jaumave	28	2	1994
Jiménez	28	2	1995
Llera	28	2	1996
Mainero	28	2	1997
El Mante	28	2	1998
Matamoros	28	2	1999
Méndez	28	2	2000
Mier	28	2	2001
Miguel Alemán	28	2	2002
Miquihuana	28	2	2003
Nuevo Laredo	28	2	2004
Nuevo Morelos	28	2	2005
Ocampo	28	2	2006
Padilla	28	2	2007
Palmillas	28	2	2008
Reynosa	28	2	2009
Río Bravo	28	2	2010
San Carlos	28	2	2011
San Fernando	28	2	2012
San Nicolás	28	2	2013
Soto la Marina	28	2	2014
Tampico	28	2	2015
Tula	28	2	2016
Valle Hermoso	28	2	2017
Victoria	28	2	2018
Villagrán	28	2	2019
Xicoténcatl	28	2	2020
Amaxac de Guerrero	29	2	2021
Apetatitlán de Antonio Carvajal	29	2	2022
Atlangatepec	29	2	2023
Atltzayanca	29	2	2024
Apizaco	29	2	2025
Calpulalpan	29	2	2026
El Carmen Tequexquitla	29	2	2027
Cuapiaxtla	29	2	2028
Cuaxomulco	29	2	2029
Chiautempan	29	2	2030
Muñoz de Domingo Arenas	29	2	2031
Españita	29	2	2032
Huamantla	29	2	2033
Hueyotlipan	29	2	2034
Ixtacuixtla de Mariano Matamoros	29	2	2035
Ixtenco	29	2	2036
Mazatecochco de José María Morelos	29	2	2037
Contla de Juan Cuamatzi	29	2	2038
Tepetitla de Lardizábal	29	2	2039
Sanctórum de Lázaro Cárdenas	29	2	2040
Nanacamilpa de Mariano Arista	29	2	2041
Acuamanala de Miguel Hidalgo	29	2	2042
Natívitas	29	2	2043
Panotla	29	2	2044
San Pablo del Monte	29	2	2045
Santa Cruz Tlaxcala	29	2	2046
Tenancingo	29	2	2047
Teolocholco	29	2	2048
Tepeyanco	29	2	2049
Terrenate	29	2	2050
Tetla de la Solidaridad	29	2	2051
Tetlatlahuca	29	2	2052
Tlaxcala	29	2	2053
Tlaxco	29	2	2054
Tocatlán	29	2	2055
Totolac	29	2	2056
Ziltlaltépec de Trinidad Sánchez Santos	29	2	2057
Tzompantepec	29	2	2058
Xaloztoc	29	2	2059
Xaltocan	29	2	2060
Papalotla de Xicohténcatl	29	2	2061
Xicohtzinco	29	2	2062
Yauhquemehcan	29	2	2063
Zacatelco	29	2	2064
Benito Juárez	29	2	2065
Emiliano Zapata	29	2	2066
Lázaro Cárdenas	29	2	2067
La Magdalena Tlaltelulco	29	2	2068
San Damián Texóloc	29	2	2069
San Francisco Tetlanohcan	29	2	2070
San Jerónimo Zacualpan	29	2	2071
San José Teacalco	29	2	2072
San Juan Huactzinco	29	2	2073
San Lorenzo Axocomanitla	29	2	2074
San Lucas Tecopilco	29	2	2075
Santa Ana Nopalucan	29	2	2076
Santa Apolonia Teacalco	29	2	2077
Santa Catarina Ayometla	29	2	2078
Santa Cruz Quilehtla	29	2	2079
Santa Isabel Xiloxoxtla	29	2	2080
Acajete	30	2	2081
Acatlán	30	2	2082
Acayucan	30	2	2083
Actopan	30	2	2084
Acula	30	2	2085
Acultzingo	30	2	2086
Camarón de Tejeda	30	2	2087
Alpatláhuac	30	2	2088
Alto Lucero de Gutiérrez Barrios	30	2	2089
Altotonga	30	2	2090
Alvarado	30	2	2091
Amatitlán	30	2	2092
Naranjos Amatlán	30	2	2093
Amatlán de los Reyes	30	2	2094
Angel R. Cabada	30	2	2095
La Antigua	30	2	2096
Apazapan	30	2	2097
Aquila	30	2	2098
Astacinga	30	2	2099
Atlahuilco	30	2	2100
Atoyac	30	2	2101
Atzacan	30	2	2102
Atzalan	30	2	2103
Tlaltetela	30	2	2104
Ayahualulco	30	2	2105
Banderilla	30	2	2106
Benito Juárez	30	2	2107
Boca del Río	30	2	2108
Calcahualco	30	2	2109
Camerino Z. Mendoza	30	2	2110
Carrillo Puerto	30	2	2111
Catemaco	30	2	2112
Cazones de Herrera	30	2	2113
Cerro Azul	30	2	2114
Citlaltépetl	30	2	2115
Coacoatzintla	30	2	2116
Coahuitlán	30	2	2117
Coatepec	30	2	2118
Coatzacoalcos	30	2	2119
Coatzintla	30	2	2120
Coetzala	30	2	2121
Colipa	30	2	2122
Comapa	30	2	2123
Córdoba	30	2	2124
Cosamaloapan de Carpio	30	2	2125
Cosautlán de Carvajal	30	2	2126
Coscomatepec	30	2	2127
Cosoleacaque	30	2	2128
Cotaxtla	30	2	2129
Coxquihui	30	2	2130
Coyutla	30	2	2131
Cuichapa	30	2	2132
Cuitláhuac	30	2	2133
Chacaltianguis	30	2	2134
Chalma	30	2	2135
Chiconamel	30	2	2136
Chiconquiaco	30	2	2137
Chicontepec	30	2	2138
Chinameca	30	2	2139
Chinampa de Gorostiza	30	2	2140
Las Choapas	30	2	2141
Chocamán	30	2	2142
Chontla	30	2	2143
Chumatlán	30	2	2144
Emiliano Zapata	30	2	2145
Espinal	30	2	2146
Filomeno Mata	30	2	2147
Fortín	30	2	2148
Gutiérrez Zamora	30	2	2149
Hidalgotitlán	30	2	2150
Huatusco	30	2	2151
Huayacocotla	30	2	2152
Hueyapan de Ocampo	30	2	2153
Huiloapan de Cuauhtémoc	30	2	2154
Ignacio de la Llave	30	2	2155
Ilamatlán	30	2	2156
Isla	30	2	2157
Ixcatepec	30	2	2158
Ixhuacán de los Reyes	30	2	2159
Ixhuatlán del Café	30	2	2160
Ixhuatlancillo	30	2	2161
Ixhuatlán del Sureste	30	2	2162
Ixhuatlán de Madero	30	2	2163
Ixmatlahuacan	30	2	2164
Ixtaczoquitlán	30	2	2165
Jalacingo	30	2	2166
Xalapa	30	2	2167
Jalcomulco	30	2	2168
Jáltipan	30	2	2169
Jamapa	30	2	2170
Jesús Carranza	30	2	2171
Xico	30	2	2172
Jilotepec	30	2	2173
Juan Rodríguez Clara	30	2	2174
Juchique de Ferrer	30	2	2175
Landero y Coss	30	2	2176
Lerdo de Tejada	30	2	2177
Magdalena	30	2	2178
Maltrata	30	2	2179
Manlio Fabio Altamirano	30	2	2180
Mariano Escobedo	30	2	2181
Martínez de la Torre	30	2	2182
Mecatlán	30	2	2183
Mecayapan	30	2	2184
Medellín	30	2	2185
Miahuatlán	30	2	2186
Las Minas	30	2	2187
Minatitlán	30	2	2188
Misantla	30	2	2189
Mixtla de Altamirano	30	2	2190
Moloacán	30	2	2191
Naolinco	30	2	2192
Naranjal	30	2	2193
Nautla	30	2	2194
Nogales	30	2	2195
Oluta	30	2	2196
Omealca	30	2	2197
Orizaba	30	2	2198
Otatitlán	30	2	2199
Oteapan	30	2	2200
Ozuluama de Mascareñas	30	2	2201
Pajapan	30	2	2202
Pánuco	30	2	2203
Papantla	30	2	2204
Paso del Macho	30	2	2205
Paso de Ovejas	30	2	2206
La Perla	30	2	2207
Perote	30	2	2208
Platón Sánchez	30	2	2209
Playa Vicente	30	2	2210
Poza Rica de Hidalgo	30	2	2211
Las Vigas de Ramírez	30	2	2212
Pueblo Viejo	30	2	2213
Puente Nacional	30	2	2214
Rafael Delgado	30	2	2215
Rafael Lucio	30	2	2216
Los Reyes	30	2	2217
Río Blanco	30	2	2218
Saltabarranca	30	2	2219
San Andrés Tenejapan	30	2	2220
San Andrés Tuxtla	30	2	2221
San Juan Evangelista	30	2	2222
Santiago Tuxtla	30	2	2223
Sayula de Alemán	30	2	2224
Soconusco	30	2	2225
Sochiapa	30	2	2226
Soledad Atzompa	30	2	2227
Soledad de Doblado	30	2	2228
Soteapan	30	2	2229
Tamalín	30	2	2230
Tamiahua	30	2	2231
Tampico Alto	30	2	2232
Tancoco	30	2	2233
Tantima	30	2	2234
Tantoyuca	30	2	2235
Tatatila	30	2	2236
Castillo de Teayo	30	2	2237
Tecolutla	30	2	2238
Tehuipango	30	2	2239
Álamo Temapache	30	2	2240
Tempoal	30	2	2241
Tenampa	30	2	2242
Tenochtitlán	30	2	2243
Teocelo	30	2	2244
Tepatlaxco	30	2	2245
Tepetlán	30	2	2246
Tepetzintla	30	2	2247
Tequila	30	2	2248
José Azueta	30	2	2249
Texcatepec	30	2	2250
Texhuacán	30	2	2251
Texistepec	30	2	2252
Tezonapa	30	2	2253
Tierra Blanca	30	2	2254
Tihuatlán	30	2	2255
Tlacojalpan	30	2	2256
Tlacolulan	30	2	2257
Tlacotalpan	30	2	2258
Tlacotepec de Mejía	30	2	2259
Tlachichilco	30	2	2260
Tlalixcoyan	30	2	2261
Tlalnelhuayocan	30	2	2262
Tlapacoyan	30	2	2263
Tlaquilpa	30	2	2264
Tlilapan	30	2	2265
Tomatlán	30	2	2266
Tonayán	30	2	2267
Totutla	30	2	2268
Tuxpan	30	2	2269
Tuxtilla	30	2	2270
Ursulo Galván	30	2	2271
Vega de Alatorre	30	2	2272
Veracruz	30	2	2273
Villa Aldama	30	2	2274
Xoxocotla	30	2	2275
Yanga	30	2	2276
Yecuatla	30	2	2277
Zacualpan	30	2	2278
Zaragoza	30	2	2279
Zentla	30	2	2280
Zongolica	30	2	2281
Zontecomatlán de López y Fuentes	30	2	2282
Zozocolco de Hidalgo	30	2	2283
Agua Dulce	30	2	2284
El Higo	30	2	2285
Nanchital de Lázaro Cárdenas del Río	30	2	2286
Tres Valles	30	2	2287
Carlos A. Carrillo	30	2	2288
Tatahuicapan de Juárez	30	2	2289
Uxpanapa	30	2	2290
San Rafael	30	2	2291
Santiago Sochiapan	30	2	2292
Abalá	31	2	2293
Acanceh	31	2	2294
Akil	31	2	2295
Baca	31	2	2296
Bokobá	31	2	2297
Buctzotz	31	2	2298
Cacalchén	31	2	2299
Calotmul	31	2	2300
Cansahcab	31	2	2301
Cantamayec	31	2	2302
Celestún	31	2	2303
Cenotillo	31	2	2304
Conkal	31	2	2305
Cuncunul	31	2	2306
Cuzamá	31	2	2307
Chacsinkín	31	2	2308
Chankom	31	2	2309
Chapab	31	2	2310
Chemax	31	2	2311
Chicxulub Pueblo	31	2	2312
Chichimilá	31	2	2313
Chikindzonot	31	2	2314
Chocholá	31	2	2315
Chumayel	31	2	2316
Dzán	31	2	2317
Dzemul	31	2	2318
Dzidzantún	31	2	2319
Dzilam de Bravo	31	2	2320
Dzilam González	31	2	2321
Dzitás	31	2	2322
Dzoncauich	31	2	2323
Espita	31	2	2324
Halachó	31	2	2325
Hocabá	31	2	2326
Hoctún	31	2	2327
Homún	31	2	2328
Huhí	31	2	2329
Hunucmá	31	2	2330
Ixil	31	2	2331
Izamal	31	2	2332
Kanasín	31	2	2333
Kantunil	31	2	2334
Kaua	31	2	2335
Kinchil	31	2	2336
Kopomá	31	2	2337
Mama	31	2	2338
Maní	31	2	2339
Maxcanú	31	2	2340
Mayapán	31	2	2341
Mérida	31	2	2342
Mocochá	31	2	2343
Motul	31	2	2344
Muna	31	2	2345
Muxupip	31	2	2346
Opichén	31	2	2347
Oxkutzcab	31	2	2348
Panabá	31	2	2349
Peto	31	2	2350
Progreso	31	2	2351
Quintana Roo	31	2	2352
Río Lagartos	31	2	2353
Sacalum	31	2	2354
Samahil	31	2	2355
Sanahcat	31	2	2356
San Felipe	31	2	2357
Santa Elena	31	2	2358
Seyé	31	2	2359
Sinanché	31	2	2360
Sotuta	31	2	2361
Sucilá	31	2	2362
Sudzal	31	2	2363
Suma	31	2	2364
Tahdziú	31	2	2365
Tahmek	31	2	2366
Teabo	31	2	2367
Tecoh	31	2	2368
Tekal de Venegas	31	2	2369
Tekantó	31	2	2370
Tekax	31	2	2371
Tekit	31	2	2372
Tekom	31	2	2373
Telchac Pueblo	31	2	2374
Telchac Puerto	31	2	2375
Temax	31	2	2376
Temozón	31	2	2377
Tepakán	31	2	2378
Tetiz	31	2	2379
Teya	31	2	2380
Ticul	31	2	2381
Timucuy	31	2	2382
Tinum	31	2	2383
Tixcacalcupul	31	2	2384
Tixkokob	31	2	2385
Tixmehuac	31	2	2386
Tixpéhual	31	2	2387
Tizimín	31	2	2388
Tunkás	31	2	2389
Tzucacab	31	2	2390
Uayma	31	2	2391
Ucú	31	2	2392
Umán	31	2	2393
Valladolid	31	2	2394
Xocchel	31	2	2395
Yaxcabá	31	2	2396
Yaxkukul	31	2	2397
Yobaín	31	2	2398
Apozol	32	2	2399
Apulco	32	2	2400
Atolinga	32	2	2401
Benito Juárez	32	2	2402
Calera	32	2	2403
Cañitas de Felipe Pescador	32	2	2404
Concepción del Oro	32	2	2405
Cuauhtémoc	32	2	2406
Chalchihuites	32	2	2407
Fresnillo	32	2	2408
Trinidad García de la Cadena	32	2	2409
Genaro Codina	32	2	2410
General Enrique Estrada	32	2	2411
General Francisco R. Murguía	32	2	2412
El Plateado de Joaquín Amaro	32	2	2413
General Pánfilo Natera	32	2	2414
Guadalupe	32	2	2415
Huanusco	32	2	2416
Jalpa	32	2	2417
Jerez	32	2	2418
Jiménez del Teul	32	2	2419
Juan Aldama	32	2	2420
Juchipila	32	2	2421
Loreto	32	2	2422
Luis Moya	32	2	2423
Mazapil	32	2	2424
Melchor Ocampo	32	2	2425
Mezquital del Oro	32	2	2426
Miguel Auza	32	2	2427
Momax	32	2	2428
Monte Escobedo	32	2	2429
Morelos	32	2	2430
Moyahua de Estrada	32	2	2431
Nochistlán de Mejía	32	2	2432
Noria de Ángeles	32	2	2433
Ojocaliente	32	2	2434
Pánuco	32	2	2435
Pinos	32	2	2436
Río Grande	32	2	2437
Sain Alto	32	2	2438
El Salvador	32	2	2439
Sombrerete	32	2	2440
Susticacán	32	2	2441
Tabasco	32	2	2442
Tepechitlán	32	2	2443
Tepetongo	32	2	2444
Teúl de González Ortega	32	2	2445
Tlaltenango de Sánchez Román	32	2	2446
Valparaíso	32	2	2447
Vetagrande	32	2	2448
Villa de Cos	32	2	2449
Villa García	32	2	2450
Villa González Ortega	32	2	2451
Villa Hidalgo	32	2	2452
Villanueva	32	2	2453
Zacatecas	32	2	2454
Trancoso	32	2	2455
Santa María de la Paz	32	2	2456
xx	33	1	2457
\.


--
-- Name: gral_mun_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_mun_id_seq', 1, false);


--
-- Data for Name: gral_pais; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_pais (id, titulo, abreviacion) FROM stdin;
1	United States of America	USA
2	Mexico	MX
\.


--
-- Name: gral_pais_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_pais_id_seq', 2, true);


--
-- Data for Name: gral_puestos; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_puestos (id, titulo, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja, gral_emp_id, gral_suc_id) FROM stdin;
2	AGENTE DE VENTAS	f	2013-02-26 19:13:14.532843-05	2013-11-21 05:10:27.829662-05	\N	1	1	0	1	1
1	ADMINISTRADOR	f	2013-02-26 19:12:47.25157-05	\N	\N	1	1	0	1	1
\.


--
-- Name: gral_puestos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_puestos_id_seq', 2, true);


--
-- Data for Name: gral_religions; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_religions (id, titulo, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja, gral_emp_id, gral_suc_id) FROM stdin;
1	CATOLICA	f	2013-02-26 19:14:54.539353-05	\N	\N	1	1	0	1	1
\.


--
-- Name: gral_religions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_religions_id_seq', 1, false);


--
-- Data for Name: gral_rol; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_rol (id, titulo, authority, borrado_logico, gral_app_id) FROM stdin;
1	ADMINISTRADOR	ROLE_ADMIN	f	0
3	FACTURACION	ROLE_FACTURACION	f	0
4	COBRANZA	ROLE_COBRANZA	f	0
5	AUTORIZACION PEDIDO	ROLE_AUTORIZA_PEDIDO	f	0
6	ALTA CLIENTES	ROLE_ALTA_CLIENTE	f	0
7	ALTA PRODUCTO	ROLE_ALTA_PRODUCTO	f	0
8	REPORTE FACUTRAS	ROLE_REPORTE_FACTURAS	f	0
9	CUENTAS POR COBRAR  REPORTE VENTAS	ROLE_CXC_REPORTE_VENTAS	f	0
10	ALTA FORMULA	ROLE_ALTA_FORMULA	f	0
12	REPORTE ESTADO DE CUENTA CLIENTE	ROLE_REPORTE_EDO_CTA_CLIENTE	f	0
13	CUENTAS POR COBRAR  REPORTE ANTIGUEDAD DE SALDOS	ROLE_REPORTE_ANT_SALDOS_CXC	f	0
14	CUENTAS POR COBRAR  REPORTE PRONOSTICO	ROLE_REPORTE_CXC_PRONOSTICO	f	0
15	CONSULTAS ALMACEN	ROLE_CONSULTAS_ALMACEN	f	0
18	ALTA AGENTE	ROLE_ALTA_AGENTE	f	0
20	CREDITOS	ROLE_CREDITOS	f	0
21	REPORTE REMISIONES	ROLE_REPORTE_REMISIONES	f	0
22	REPORTE DE PROGRAMACION DE PAGOS	ROLE_REPORTE_PROG_PAGOS	f	0
25	NOTA DE CREDITO	ROLE_NOTA_CREDITO	f	0
2	VENTAS	ROLE_VENTAS	f	0
26	PROGRAMACION DE RUTA	ROLE_PROGRAMA_RUTA	f	0
27	REPORTE ESTADISTICO DE VENTAS	ROLE_REPORTE_ESTADISTICO_VENTAS	f	0
28	REPORTE  PEDIDOS	ROLE_REPORTE_PEDIDOS	f	0
30	ASIGNACION DE RUTAS	ROLE_ASIGNA_RUTA	f	0
32	ALTA DE VEHICULOS	ROLE_ALTA_VEHICULO	f	0
34	CATALOGO DE PUESTOS	ROLE_ALTA_PUESTO	f	0
35	COTIZACIONES	ROLE_COTIZACION	f	0
37	PAGOS ATICIPO A PROVEEDORES	ROLE_ANTICIPOS_CXP	f	0
44	CATALOGO DE EMPLEADOS	ROLE_ALTA_EMPLEADO	f	0
47	REPORTE REMISIONES FACTURADAS	ROLE_REPORTE_REMISIONES_FACTURADAS	f	0
50	CATALOGO ESCOLARIDADES	ROLE_ALTA_ESCOLARIDAD	f	0
51	CATALOGO DE RELIGIONES	ROLE_ALTA_RELIGION	f	0
52	CATALOGO DE TIPOS DE SANGRE	ROLE_ALTA_TIPO_SANGRE	f	0
53	CATALOGO DE TIPO DE EQUIPOS	ROLE_ALTA_TIPO_EQUIPO	f	0
54	CATALOGO DE DIAS NO LABORALES	ROLE_ALTA_DIA_NO_LABORABLE	f	0
55	CATALOGO DE CATEGORIAS DE EMPLEADO	ROLE_ALTA_CATGORIA_EMPLEADO	f	0
56	CATALOGO DE DEPARTAMENTOS	ROLE_ALTA_DEPARTAMENTO	f	0
57	CATALOGO DE TURNOS	ROLE_ALTA_TURNO	f	0
58	IMPRESION DE ETIQUETAS	ROLE_IMPRESION_ETIQUETAS	f	0
11	NOTAS DE CREDITO DE PROVEEDORES	ROLE_NOTA_CREDITO_PROVEEDOR	f	0
59	REPORTE DE ESTADO DE CUENTA DE PROVEEDORES	ROLE_REP_EDOCTA_PROVEEDOR	f	0
60	ACTUALIZAR CODIGOS ISO	ROLE_ACTUALIZA_CODIGO_ISO	f	0
62	DEVOLUCIONES A PROVEEDORES	ROLE_DEVOLUCION_A_PROVEEDOR	f	0
63	TRASPASO DE MERCANCIA A ENTRE ALMACENES	ROLE_TRASPASOS	f	0
79	ACTUALIZAR TIPO DE CAMBIO	ROLE_ACTUALIZADOR_TIPO_CAMBIO	f	0
29	PRO CONFIGURACION DE PRODUCCION	ROLE_CONFIG_PRODUCCION	f	0
23	CATALOGO DE BANCOS DE BANCOS	ROLE_ALTA_BANCOS	f	0
24	CATALOGO DE CHEQUERAS	ROLE_ALTA_CHEQUERA	f	0
90	COTIZACIONES-CONFIGURACION DE SALUDO Y DESPEDIDA	ROLE_COTIZACION_CONF_SALUDO_DESPEDIDA	f	0
19	CXCP-FACTURAS DE PROVEEDORES	ROLE_FAC_PROVEEDOR	f	0
31	INV_CATALOGO DE UNIDADES DE MEDIDA	ROLE_ALTA_UNIDAD_MEDIDA	f	0
33	FAC-FACTURAS DEVOLUCIONES	ROLE_FAC_DEVOLUCIONES	f	0
36	CXP-PAGO A PROVEEDORES	ROLE_PAGOS_CXP	f	0
38	INV-CATALOGO DE FAMILIAS	ROLE_ALTA_FAMILIA	f	0
39	INV-CATALOGO DE SUBFAMILIAS	ROLE_ALTA_SUBFAMILIA	f	0
41	INV-ORDEN DE ENTRADA	ROLE_ORDEN_DE_ENTRADA	f	0
42	INV-ORDEN DE SALIDA	ROLE_ORDEN_DE_SALIDA	f	0
43	INV-AJUSTE DE INVENTARIO	ROLE_AJUSTE_INVENTARIO	f	0
45	COM-ORDEN DE COMPRA	ROLE_ORDEN_COMPRA	f	0
46	COM-AUTORIZACION ORDEN COMPRA	ROLE_AUTORIZACION_ORDEN_COMPRA	f	0
48	PRO-ORDEN DE PRODUCCION	ROLE_ORDEN_PRODUCCION	f	0
49	PRO-PRE-ORDEN PRODUCCION	ROLE_PREORDEN_PRODUCCION	f	0
61	INV-REPORTE DE EXISTENCIAS POR LOTE	ROLE_REPORTE_EXIS_LOTE	f	0
64	INV-ORDENES DE TRASPASO	ROLE_ORDEN_TRASPASO	f	0
65	CTB-CATALOGO DE CENTROS DE COSTO	ROLE_CAT_CENTRO_COSTO	f	0
66	CTB-CATALOGO DE TIPOS DE POLIZAS	ROLE_CAT_TIPO_POLIZA	f	0
67	CTB-CATALOGO DE CUENTAS DE MAYOR	ROLE_CAT_CTA_MAYOR	f	0
68	CTB-CATALOGO DE CONCEPTOS CONTABLES	ROLE_CAT_CON_CONTABLE	f	0
70	INV-LISTA DE PRECIOS	ROLE_LISTA_PRECIOS	f	0
71	CXC-DIRECCIONES FISCALES DE CLIENTES	ROLE_DIR_FISCAL_CLIENTE	f	0
78	INV-DESCARGA FICHA TECNICA DE PRODUCTO	ROLE_DESCARGA_FICHA_TECNICA	f	0
85	INV-CONTROL DE COSTOS(CALCULO DE PRECIO MINIMO)	ROLE_CONTROL_COSTOS	f	0
87	PRO FORMULAS EN DESARROLLO	ROLE_PRO_FORMULAS_DESARROLLO	t	0
88	PRO SIMULACION DE PRODUCCION	ROLE_PRO_SIMULACION_PRODUCCION	t	0
89	PRO CATALOGO DE INSTRUMENTOS DE MEDICION	ROLE_PRO_INSTRUMENTOS_MEDICION	t	0
91	PRO REPORTE DE PRODUCCION	ROLE_PRO_REPORTE_PRODUCCION	t	0
94	INV-CATALOGO DE PRODUCTOS EQUIVALENTES	ROLE_ALTA_PRODUCTOS_EQUIV	f	0
93	COTIZACIONES-CATALOGO DE INCOTERMS	ROLE_CATALOGO_INCOTERMS	f	0
96	CXC-REPORTE DE CLIENTES	ROLE_CXC_REPORTE_CLIENTES	f	0
73	CRM CATALOGO FORMAS DE CONTACTO	ROLE_CRM_CATALOGO_FORMAS_CONTACTO	f	0
74	CRM CATALOGO MOTIVOS DE LLAMADA	ROLE_CRM_CATALOGO_MOTIVOS_LLAMADA	f	0
75	CRM CATALOGO MOTIVOS DE VISITA	ROLE_CRM_CATALOGO_MOTIVOS_VISITA	f	0
76	CRM REGISTRO DE OPORTUNIDADES	ROLE_CRM_REGISTRO_OPORTUNIDADES	f	0
77	CRM CATALOGO DE PROSPECTOS	ROLE_CRM_CATALOGO_PROSPECTOS	f	0
80	CRM CATALOGO DE CONTACTOS	ROLE_CRM_CATALOGO_CONTACTOS	f	0
81	CRM REGISTRO DE LLAMADAS	ROLE_CRM_REGISTRO_LLAMADAS	f	0
82	CRM REGISTRO DE METAS	ROLE_CRM_REGISTRO_METAS	f	0
83	CRM REGISTRO DE CASOS	ROLE_CRM_REGISTRO_CASOS	f	0
84	CRM CONSULTAS	ROLE_CRM_CONSULTAS	f	0
92	CRM REPORTE DE VISITAS	ROLE_CRM_REPORTE_VISITAS	f	0
95	INV-REPORTE DE MOVIMIENTOS DE INVETARIO	ROLE_REPORTE_INV_MOV	f	0
97	COTIZACIONES - CATALOGO DE POLITICAS DE PAGO	ROLE_COT_POLITICAS_PAGO	f	0
99	ENV-PROCESO DE RE-ENVASADO	ROLE_ENV_REENVASADO	f	0
98	ENV-CONFIGURACION DE ENVASADO	ROLE_ENV_CONFIGURACION	f	0
101	ORDEN PRODUCCION DE SUBENSAMBLE	ROLE_ORDEN_PRODUCCION_SUBENSAMBLE	f	0
102	PROCESO DE PRODUCCION DE SUBENSAMBLE	ROLE_PRODUCCION_SUBENSAMBLE	f	0
100	FAC-CANCELACION DE FACTURAS	ROLE_FAC_CANCELACION	f	0
103	FAC-CONSULTA DE FACTURAS	ROLE_FAC_CONSULTAS	f	0
107	REPORTE DE COMPRAS NETAS POR PRODUCTO	ROLE_COMPRAS_NETAS_PRODUCTO	f	0
139	CXC-CANCALACION DE ANTICIPOS	ROLE_CXC_CANCELA_ANTICIPO	f	0
140	CXP-REPORTE SALDO MENSUAL DE PROVEEDORES	ROLE_CXP_REP_SALDO_MES	f	0
141	CXC-CATALOGO DE REMITENTES	ROLE_CXC_REMITENTES	f	0
142	CXC-CATALOGO DE DESTINATARIOS	ROLE_CXC_DESTINATARIOS	f	0
143	CXC-CATALOGO DE AGENTES ADUANALES	ROLE_CXC_AGEN_ADUANAL	f	0
144	CXC-ASIGNACION DE REMITENTES	ROLE_CXC_ASIGNA_REMITENTE	f	0
145	CXC-REPORTE DE SALDO MENSUAL DE CLIENTES	ROLE_CXC_REP_SALDO_MES	f	0
146	COM-CAPTURA DE COSTO DE REPOSICION	ROLE_CAPTURA_COSTO_REPOSICION	f	0
147	COM-REPORTE DE DIAS DE ENTREGA O.C.	ROLE_CXP_REP_OC_DIAS_ENTREGA	f	0
149	CXP-REPORTE DE PROVEEDORES	ROLE_CXP_REP_PROVEEDORES	f	0
150	CATALOGO DE IEPS	ROLE_GRAL_IEPS	f	0
151	CXC-REPORTE COMPARATIVO DE VENTAS ANUALES POR CLIENTE	ROLE_CXC_REP_COMP_VENTAS_CLIENTE	f	0
153	NOMINA-CATALOGO DE PERCEPCIONES	ROLE_GRAL_CATALOGO_PRECEP	f	0
148	LOG-CATALOGO DE OPERADORES(CHOFERES)	ROLE_LOG_OPERADORES	t	0
152	CXC-REPORTE COMPARATIVO DE VENTAS ANUALES POR PRODUCTO	ROLE_CXC_REP_COMP_VENTAS_PROD	f	0
154	NOMINA-CATALOGO DE DEDUCCIONES	ROLE_GRAL_CATALOGO_DEDUC	f	0
115	NOMINA-GENERAR CFDI DE NOMINA	ROLE_FAC_NOMINA	f	0
116	NOMINA-CONFIGURACION DE PERIODOS DE PAGO	ROLE_GRAL_CONFIG_PERIODOS_PAGO	f	0
118	INV-CARGA DE INVENTARIO FISICO	ROLE_CARGA_INV_FISICO	f	0
155	CXC-REPORTE DE IEPS COBRADO	ROLE_CXC_IEPS_COBRADO	f	0
160	CXP-REPORTE DE IEPS PAGADO	ROLE_CXP_IEPS_PAGADO	f	0
163	CTB-POLIZAS CONTABLES	ROLE_CTB_POLIZA_CONTABLE	f	0
164	LOG-CATALOGO DE MARCAS DE UNIDAD(CAMIONES)	ROLE_LOG_UNIDAD_MARCA	t	0
165	LOG-CATALOGO DE TIPO DE CAJA DE UNIDAD	ROLE_LOG_UNIDAD_TIPO_CAJA	t	0
166	LOG-CATALOGO DE TIPO DE RODADA DE UNIDADES	ROLE_LOG_UNIDAD_TIPO_RODADA	t	0
162	LOG-ADMINISTRADOR DE VIAJES	ROLE_LOG_ADM_VIAJE	t	0
161	LOG-CARGA DE DOCUMENTOS	ROLE_LOG_CARGA_DOC	t	0
138	PRO-REPORTE DE CALIDAD	ROLE_PRO_REPORTE_CALIDAD	t	0
117	COM-REPORTE DE BACKORDER	ROLE_COM_REP_BACKORDER	t	0
104	PRO-CATALOGO DE EQUIPOS ADICIONALES	ROLE_PRO_EQUIPOS_ADICIONALES	t	0
105	PRO-CATALOGO DE EQUIPOS	ROLE_PRO_EQUIPOS	t	0
106	PRO-ASEGURAMIENTO DE CALIDAD DE LA PRODUCCION	ROLE_PRO_ASEG_CALIDAD	t	0
170	CXP-REPORTE DE PAGOS DIARIOS	ROLE_CXP_REP_PAGO_DIARIO	f	0
167	LOG-CATALOGO DE TIPOS DE UNIDADES(VEHICULOS)	ROLE_LOG_TIPO_UNIDAD	t	0
168	LOG-REGISTRO DE CARGAS	ROLE_LOG_REG_CARGA	t	0
169	LOG-CATALOGO DE RUTAS-TARIFARIO	ROLE_LOG_TARIFARIO	t	0
16	CXP-CATALOGO DE PROVEEDORES	ROLE_ALTA_PROVEEDOR	f	0
17	COM-FACTURAS DE COMPRAS	ROLE_FACTURAS_COMPRAS	f	0
40	CXC-REPORTE COBRANZA DIARIA	ROLE_REPORTE_COBRANZA_DIARIA	f	0
69	CTB-CATALOGO DE CUENTAS CONTABLES	ROLE_CAT_CTAS_CONTABLES	f	0
86	INV-ACTUALIZADOR DE PRECIOS A PARTIR DEL PRECIO MINIMO	ROLE_ACTUALIZA_PRECIOS	f	0
121	INV-IMPRESION DE ETIQUETAS DE SALIDA	ROLE_IMPRESION_ETIQUETA_SALIDA	f	0
123	LOG-CATALOGO DE TIPOS DE RECHAZO	ROLE_LOG_TIPOS_RECHAZO	t	0
124	FAC-REMISIONES	ROLE_FAC_REMS	f	0
125	CTB-REPORTE DE AUXILIAR DE MOVIMIENTOS DE CUENTAS	ROLE_CTB_REP_AUX_MOV_CTA	f	0
126	CTB-REPORTE DE BALANZA DE COMPROBACION	ROLE_CTB_REP_BALANZA_COMP	f	0
127	CTB-REPORTE DE BALANCE GENERAL	ROLE_CTB_REP_BALANCE_GRAL	f	0
130	LOG-CAPTURA DE EVIDENCIAS DEL VIAJE	ROLE_LOG_EVIDENCIAS	f	0
179	CRM-REGISTRO DE PROYECTOS	ROLE_CRM_REGISTRO_PROYECTO	f	0
72	CRM REGISTRO DE VISITAS	ROLE_CRM_REGISTRO_VISITA	f	0
180	CXC-REPORTE COMERCIAL	ROLE_CXC_REPORTE_COMERCIAL	f	0
181	CRM-CATALOGO DE TIPOS DE SEGUIMIENTO DE VISITAS	ROLE_CRM_TIPO_SEGUIMIENTO_VISITA	f	0
\.


--
-- Name: gral_rol_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_rol_id_seq', 1, false);


--
-- Data for Name: gral_sangretipos; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_sangretipos (id, titulo, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja, gral_emp_id, gral_suc_id) FROM stdin;
1	AB-	f	2013-02-26 19:15:31.770523-05	\N	\N	1	1	0	1	1
\.


--
-- Name: gral_sangretipos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_sangretipos_id_seq', 1, true);


--
-- Data for Name: gral_sexos; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_sexos (id, titulo, borrado_logico) FROM stdin;
1	Hombre	f
2	Mujer	f
\.


--
-- Name: gral_sexos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_sexos_id_seq', 1, false);


--
-- Data for Name: gral_suc; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_suc (id, titulo, cp, colonia, calle, numero_interior, numero_exterior, borrado_logico, empresa_id, momento_creacion, momento_actualizacion, momento_baja, gral_pais_id, gral_edo_id, gral_mun_id, gral_impto_id, email, clave) FROM stdin;
1	MTY_KEMIKAL	66600	PARQUE INDUSTRIAL JM	AV. JM	\N	206	f	1	2010-12-21 18:30:57.599-05	2010-12-21 18:30:57.599-05	\N	2	19	953	1	fabianaguayo@kemikalmexico.com.mx	MTY
\.


--
-- Name: gral_suc_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_suc_id_seq', 1, true);


--
-- Data for Name: gral_tc_url; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_tc_url (id, url, institucion) FROM stdin;
1	http://dof.gob.mx/indicadores.xml	DOF
\.


--
-- Name: gral_tc_url_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_tc_url_id_seq', 1, false);


--
-- Data for Name: gral_usr; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_usr (id, username, password, enabled, ultimo_acceso, gral_empleados_id) FROM stdin;
1	admin	123qwe	t	2016-08-04 21:17:17.230912-04	1
\.


--
-- Name: gral_usr_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_usr_id_seq', 1, true);


--
-- Data for Name: gral_usr_rol; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_usr_rol (id, gral_usr_id, gral_rol_id) FROM stdin;
1	1	1
\.


--
-- Name: gral_usr_rol_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_usr_rol_id_seq', 1, false);


--
-- Data for Name: gral_usr_suc; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_usr_suc (id, gral_usr_id, gral_suc_id) FROM stdin;
1	1	1
\.


--
-- Name: gral_usr_suc_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_usr_suc_id_seq', 1, false);


--
-- Name: denominacion_vers_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY erp_monedavers
    ADD CONSTRAINT denominacion_vers_pkey PRIMARY KEY (id);


--
-- Name: erp_users_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_usr
    ADD CONSTRAINT erp_users_pkey PRIMARY KEY (id);


--
-- Name: gral_categ_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_categ
    ADD CONSTRAINT gral_categ_pkey PRIMARY KEY (id);


--
-- Name: gral_civils_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_civils
    ADD CONSTRAINT gral_civils_pkey PRIMARY KEY (id);


--
-- Name: gral_deptos_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_deptos
    ADD CONSTRAINT gral_deptos_pkey PRIMARY KEY (id);


--
-- Name: gral_edo_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_edo
    ADD CONSTRAINT gral_edo_pkey PRIMARY KEY (id);


--
-- Name: gral_emails_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_emails
    ADD CONSTRAINT gral_emails_pkey PRIMARY KEY (id);


--
-- Name: gral_emp_leyenda_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_emp_leyenda
    ADD CONSTRAINT gral_emp_leyenda_pkey PRIMARY KEY (id);


--
-- Name: gral_empleados_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_empleados
    ADD CONSTRAINT gral_empleados_pkey PRIMARY KEY (id);


--
-- Name: gral_escolaridads_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_escolaridads
    ADD CONSTRAINT gral_escolaridads_pkey PRIMARY KEY (id);


--
-- Name: gral_imptos_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_imptos
    ADD CONSTRAINT gral_imptos_pkey PRIMARY KEY (id);


--
-- Name: gral_mon_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_mon
    ADD CONSTRAINT gral_mon_pkey PRIMARY KEY (id);


--
-- Name: gral_mun_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_mun
    ADD CONSTRAINT gral_mun_pkey PRIMARY KEY (id);


--
-- Name: gral_pais_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_pais
    ADD CONSTRAINT gral_pais_pkey PRIMARY KEY (id);


--
-- Name: gral_pais_titulo_key; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_pais
    ADD CONSTRAINT gral_pais_titulo_key UNIQUE (titulo);


--
-- Name: gral_puestos_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_puestos
    ADD CONSTRAINT gral_puestos_pkey PRIMARY KEY (id);


--
-- Name: gral_religions_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_religions
    ADD CONSTRAINT gral_religions_pkey PRIMARY KEY (id);


--
-- Name: gral_rols_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_rol
    ADD CONSTRAINT gral_rols_pkey PRIMARY KEY (id);


--
-- Name: gral_sangretipos_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_sangretipos
    ADD CONSTRAINT gral_sangretipos_pkey PRIMARY KEY (id);


--
-- Name: gral_sexos_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_sexos
    ADD CONSTRAINT gral_sexos_pkey PRIMARY KEY (id);


--
-- Name: gral_sis_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_emp
    ADD CONSTRAINT gral_sis_pkey PRIMARY KEY (id);


--
-- Name: gral_sis_titulo_key; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_emp
    ADD CONSTRAINT gral_sis_titulo_key UNIQUE (titulo);


--
-- Name: gral_suc_titulo_key; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_suc
    ADD CONSTRAINT gral_suc_titulo_key UNIQUE (titulo);


--
-- Name: gral_sucursales_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_suc
    ADD CONSTRAINT gral_sucursales_pkey PRIMARY KEY (id);


--
-- Name: gral_tc_url_key; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_tc_url
    ADD CONSTRAINT gral_tc_url_key UNIQUE (url);


--
-- Name: gral_tc_url_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_tc_url
    ADD CONSTRAINT gral_tc_url_pkey PRIMARY KEY (id);


--
-- Name: gral_usr_rol_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_usr_rol
    ADD CONSTRAINT gral_usr_rol_pkey PRIMARY KEY (id);


--
-- Name: gral_usr_suc_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_usr_suc
    ADD CONSTRAINT gral_usr_suc_pkey PRIMARY KEY (id);


--
-- Name: unique_emp_clave_suc; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_suc
    ADD CONSTRAINT unique_emp_clave_suc UNIQUE (empresa_id, clave, borrado_logico);


--
-- Name: unique_gral_emp_no_id; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_emp
    ADD CONSTRAINT unique_gral_emp_no_id UNIQUE (no_id);


--
-- Name: unique_gral_usr_suc; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_usr_suc
    ADD CONSTRAINT unique_gral_usr_suc UNIQUE (gral_suc_id, gral_usr_id);


--
-- Name: unique_institucion; Type: CONSTRAINT; Schema: public; Owner: sumar; Tablespace: 
--

ALTER TABLE ONLY gral_tc_url
    ADD CONSTRAINT unique_institucion UNIQUE (institucion);


--
-- Name: fk-234243; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_emp
    ADD CONSTRAINT "fk-234243" FOREIGN KEY (pais_id) REFERENCES gral_pais(id);


--
-- Name: fk-3457856; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_emp
    ADD CONSTRAINT "fk-3457856" FOREIGN KEY (municipio_id) REFERENCES gral_mun(id);


--
-- Name: fk-4234234; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_emp
    ADD CONSTRAINT "fk-4234234" FOREIGN KEY (estado_id) REFERENCES gral_edo(id);


--
-- Name: fk-42435435; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_usr_suc
    ADD CONSTRAINT "fk-42435435" FOREIGN KEY (gral_usr_id) REFERENCES gral_usr(id);


--
-- Name: fk-8656856; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_usr_suc
    ADD CONSTRAINT "fk-8656856" FOREIGN KEY (gral_suc_id) REFERENCES gral_suc(id);


--
-- Name: fk_emp_id; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_suc
    ADD CONSTRAINT fk_emp_id FOREIGN KEY (empresa_id) REFERENCES gral_emp(id);


--
-- Name: fk_gral_emp_id; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_emp_leyenda
    ADD CONSTRAINT fk_gral_emp_id FOREIGN KEY (gral_emp_id) REFERENCES gral_emp(id);


--
-- Name: fk_gral_emp_id; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_emails
    ADD CONSTRAINT fk_gral_emp_id FOREIGN KEY (gral_emp_id) REFERENCES gral_emp(id);


--
-- Name: fk_gral_suc_id; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_emails
    ADD CONSTRAINT fk_gral_suc_id FOREIGN KEY (gral_suc_id) REFERENCES gral_suc(id);


--
-- Name: fk_pais_00; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_edo
    ADD CONSTRAINT fk_pais_00 FOREIGN KEY (pais_id) REFERENCES gral_pais(id);


--
-- Name: fk_rol; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_usr_rol
    ADD CONSTRAINT fk_rol FOREIGN KEY (gral_rol_id) REFERENCES gral_rol(id);


--
-- Name: fk_suc_gral_impto_id; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_suc
    ADD CONSTRAINT fk_suc_gral_impto_id FOREIGN KEY (gral_impto_id) REFERENCES gral_imptos(id);


--
-- Name: fk_usr; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_usr_rol
    ADD CONSTRAINT fk_usr FOREIGN KEY (gral_usr_id) REFERENCES gral_usr(id);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

