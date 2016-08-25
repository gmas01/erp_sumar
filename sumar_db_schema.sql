--
-- PostgreSQL database dump
--

-- Dumped from database version 9.4.8
-- Dumped by pg_dump version 9.5.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

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
-- Name: erp_fn_validaciones_por_aplicativo(text, integer, text[]); Type: FUNCTION; Schema: public; Owner: sumar
--

CREATE FUNCTION erp_fn_validaciones_por_aplicativo(campos_data text, id_app integer, arreglo text[]) RETURNS text
    LANGUAGE plpgsql
    AS $_$

DECLARE

        -- # The store procedure's caller is expecting
        -- # an string reply. The caller is goint to be
        -- # on charge of parsing so.
	valor_retorno text := '';


	-- # Buffer array for "campos_data" splitted content
	-- # The rest of the variables over this section
	-- # are use to store any element of this array in
	-- # its original or modified form.
	str_data text[];	
	command_selected character varying:='';
	

        -- # When is ocurring 
        -- # such validation
	espacio_tiempo_ejecucion timestamp with time zone := now();
	ano_actual integer:=0;
	mes_actual integer:=0;
	

	-- # From Where and who is 
	-- # performing validation
	usuario_id integer;
	emp_id integer;
	suc_id integer;
	id_almacen integer := 0;


        -- # Store procedure setting flag variables
        -- # These group of variables control how
        -- # this store procedure is going to act
        -- # when one or more erp features are enabled
        empresa_transportista boolean;
	incluye_modulo_produccion boolean;
	incluye_modulo_contabilidad boolean;
	incluye_nomina  boolean:=false;
	validaListaPrecioCliente boolean:=false;
	controlExisPres boolean := false;
	
	
        -- # General purpose variables related with 
        -- # store procedure purpose
        record1 record;
        str_filas text[];
        str_filas2 text[];
        total_filas integer;--total de elementos de arreglo
        total_filas2 integer;--total de elementos de arreglo
        titulo_mask character varying;
	mask_general character varying;
	match_cadena boolean=false;
	valida_integridad integer;
        sql_select text;
        cadena character varying:='';
        exis integer:=0;
        cont_fila integer;--contador de filas o posiciones del arreglo
        cont_fila2 integer;--contador de filas o posiciones del arreglo


	--Estas  se utilizan para la nomina
	str_percep text[];
--	str_deduc text[];
--	str_hrs_extras text[];
--	str_incapa text[];
		
	--str_filas2 text[];
--	total_filas2 integer;--total de elementos de arreglo
	--cont_fila2 integer;--contador de filas o posiciones del arreglo

--	id_banco integer;
	


BEGIN

	SELECT EXTRACT(YEAR FROM espacio_tiempo_ejecucion) INTO ano_actual;
	SELECT EXTRACT(MONTH FROM espacio_tiempo_ejecucion) INTO mes_actual;

	SELECT INTO str_data string_to_array(''||campos_data||'','___');
	
	-- Comando que desea ejecutar el aplicativo que llamo el procedimiento almacenado
	command_selected := str_data[2];
	
	-- usuario que utiliza el aplicativo
	usuario_id := str_data[3]::integer;
	
	--RAISE EXCEPTION '%','usuario_id: '||usuario_id;
	
	--obtiene empresa_id, sucursal_id y sucursal_id
  	SELECT gral_suc.empresa_id, gral_usr_suc.gral_suc_id,inv_suc_alm.almacen_id FROM gral_usr_suc 
	JOIN gral_suc ON gral_suc.id = gral_usr_suc.gral_suc_id
	JOIN inv_suc_alm ON inv_suc_alm.sucursal_id = gral_suc.id
	WHERE gral_usr_suc.gral_usr_id=usuario_id
	INTO emp_id, suc_id, id_almacen;
	--RAISE EXCEPTION '%','emp_id: '||emp_id;
	
	--Query para verificar si la empresa actual incluye Modulo de Contabilidad, Control de Existencias por Presentacion
	SELECT incluye_produccion, incluye_contabilidad, control_exis_pres, lista_precio_clientes, transportista, nomina FROM gral_emp WHERE id=emp_id 
	INTO incluye_modulo_produccion, incluye_modulo_contabilidad, controlExisPres, validaListaPrecioCliente, empresa_transportista, incluye_nomina;


	--INICIA VALIDACION Catalogo de proveedores
	IF id_app=2 THEN
		--rfc
		IF str_data[29]::integer = 1 OR str_data[29]::integer = 0 THEN
			EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_RFCCorrect'';' INTO mask_general;
			EXECUTE 'select '''||trim(str_data[6])||''' ~ '''||mask_general||''';' INTO match_cadena;
			IF match_cadena = false THEN
				valor_retorno := ''||valor_retorno||'rfc:RFC No Valido___';
			END IF;
		END IF;
		
		--curp
		IF str_data[7] != ''  AND str_data[7] != ' ' THEN
			EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_CurpCorrect'';' INTO mask_general;
			EXECUTE 'select '''||str_data[7]||''' ~ '''||mask_general||''';' INTO match_cadena;
			IF match_cadena = false THEN
				valor_retorno := ''||valor_retorno||'curp:La CURP ingresada no es no Valida___';
			END IF;
		END IF;
		
		--razon social
		EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_RazonSocialCorrect'';' INTO mask_general;
		EXECUTE 'select '''||str_data[8]||''' ~ '''||mask_general||''';' INTO match_cadena;
		IF match_cadena = false THEN
			valor_retorno := ''||valor_retorno||'rsocial:Razon Social No Valida___';
		END IF;
		
		--nombre comercial
		EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_TituloCorrerct'';' INTO mask_general;
		EXECUTE 'select '''||str_data[9]||''' ~ '''||mask_general||''';' INTO match_cadena;
		IF match_cadena = false THEN
			valor_retorno := 'ncomercial:Nombre Comercial No Valido___';
		END IF;
		
		--calle
		EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_CalleCorrect'';' INTO mask_general;
		EXECUTE 'select '''||str_data[10]||''' ~ '''||mask_general||''';' INTO match_cadena;
		IF match_cadena = false THEN
			valor_retorno := ''||valor_retorno||'calle:Calle No Valida___';
		END IF;
		
		--num calle
		EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_AddressNumberCorrect'';' INTO mask_general;
		EXECUTE 'select '''||str_data[11]||''' ~ '''||mask_general||''';' INTO match_cadena;
		IF match_cadena = false THEN
			valor_retorno := ''||valor_retorno||'numcalle:Numero de Calle No Valida___';
		END IF;
		
		--colonia
		EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_ColoniaCorrect'';' INTO mask_general;
		EXECUTE 'select '''||str_data[12]||''' ~ '''||mask_general||''';' INTO match_cadena;
		IF match_cadena = false THEN
			valor_retorno := ''||valor_retorno||'colonia:Colonia No Valido___';
		END IF;
		
		--cp
		EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_CodigoPostalCorrect'';' INTO mask_general;
		EXECUTE 'select '''||str_data[13]||''' ~ '''||mask_general||''';' INTO match_cadena;
		IF match_cadena = false THEN
			valor_retorno := ''||valor_retorno||'cp:Codigo Postal No Valido___';
		END IF;
		
		--pais
		IF str_data[15]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'pais:Es necesario seleccionar el Pais del Proveedor___';
		END IF;
		
		--estado
		IF str_data[16]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'estado:Es necesario seleccionar el Estado del Proveedor___';
		END IF;
		
		--municipio
		IF str_data[17]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'municipio:Es necesario seleccionar el Municipio del Proveedor___';
		END IF;
		
		
		--telefono 1
		IF str_data[19]='' OR str_data[19]=' ' THEN
			valor_retorno := ''||valor_retorno||'tel1:Es necesario ingresar el numero de Teléfono___';
		ELSE
			EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_PhoneCorrect'';' INTO mask_general;
			EXECUTE 'select '''||str_data[19]||''' ~ '''||mask_general||''';' INTO match_cadena;
			IF match_cadena = false THEN
				valor_retorno := ''||valor_retorno||'tel1:Numero de Teléfono No Valido___';
			END IF;
		END IF;
		
		--e-mail
		EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_EmailCorrect'';' INTO mask_general;
		EXECUTE 'select '''||str_data[24]||''' ~ '''||mask_general||''';' INTO match_cadena;
		IF match_cadena = false THEN
			valor_retorno := ''||valor_retorno||'email:Correo Electronico No Valido___';
		END IF;
		
		--zona del proveedor
		IF str_data[27]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'zona:Es necesario seleccionar una Zona para el proveedor___';
		END IF;
		
		--grupo del proveedor
		IF str_data[28]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'grupo:Es necesario seleccionar un Grupo para el proveedor___';
		END IF;
		
		
		--tipo de proveedor
		IF str_data[29]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'provtipo:Es necesario seleccionar el Tipo de Proveedor___';
		END IF;
		
		--Clasificacion 1 del proveedor
		IF str_data[30]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'clasif1:Es necesario seleccionar un Clasificación para el proveedor___';
		END IF;
		
		--Clasificacion 2 del proveedor
		IF str_data[31]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'clasif2:Es necesario seleccionar un Clasificación para el proveedor___';
		END IF;
		
		--Clasificacion 3 del proveedor
		IF str_data[32]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'clasif3:Es necesario seleccionar un Clasificación para el proveedor___';
		END IF;
		
		
		--moneda_id del proveedor
		IF str_data[33]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'moneda:Es necesario seleccionar una moneda para el proveedor___';
		END IF;
		
		
		--dias de credito
		IF str_data[37]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'credito:Es necesario seleccionar los Días de Crédito___';
		END IF;
		
		--inicio de credito
		IF str_data[39]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'inicred:Es necesario seleccionar el Inicio del Crédito___';
		END IF;
		
		--contacto ventas
		EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_ContactoCorrect'';' INTO mask_general;
		EXECUTE 'select '''||str_data[44]||''' ~ '''||mask_general||''';' INTO match_cadena;
		IF match_cadena = false THEN
			valor_retorno := ''||valor_retorno||'vcontacto:Ingrese el Nombre del contacto___';
		END IF;
		
		--Puesto del contacto ventas
		IF str_data[45] = '' OR str_data[45] = ' ' THEN
			valor_retorno := ''||valor_retorno||'vpuesto:Es Ingresar el Puesto del Contacto___';
		END IF;
		
		
		
		--e-mail ccontacto ventas
		IF str_data[59] != '' AND str_data[59] != ' ' THEN
			EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_EmailCorrect'';' INTO mask_general;
			EXECUTE 'select '''||str_data[59]||''' ~ '''||mask_general||''';' INTO match_cadena;
			IF match_cadena = false THEN
				valor_retorno := ''||valor_retorno||'vemail:E-mail del Contacto No Valido___';
			END IF;
		END IF;
		
		
		
		--valida la integridad de los datos, si el Proveedor es Nuevo
		IF str_data[4] = '0' THEN
			IF valor_retorno = '' THEN
				IF str_data[29]::integer=1 OR str_data[29]::integer=0 THEN
					EXECUTE 'select count(id) from cxp_prov where  rfc='''||str_data[6]||'''  and borrado_logico=false AND empresa_id='||emp_id||';' INTO valida_integridad;
					IF valida_integridad > 0 THEN
						valor_retorno := ''||valor_retorno||'rfc:El RFC ingresado ya se encuentra en uso___';
					END IF;
				END IF;
			END IF;
			IF valor_retorno = '' THEN
				EXECUTE 'select count(id) from cxp_prov where  razon_social='''||str_data[8]||''' and borrado_logico=false AND empresa_id='||emp_id||';' INTO valida_integridad;
				IF valida_integridad > 0 THEN
					valor_retorno := ''||valor_retorno||'rsocial:La Razon Social ingresada ya se encuentra en uso___';
				END IF;
			END IF;
			IF valor_retorno = '' THEN
				EXECUTE 'select count(id) from cxp_prov where clave_comercial='''||str_data[9]||''' and borrado_logico=false AND empresa_id='||emp_id||';' INTO valida_integridad;
				IF valida_integridad > 0 THEN
					valor_retorno := ''||valor_retorno||'ncomercial:El Nombre comercial ingresado ya se encuentra en uso___';
				END IF;
			END IF;
			IF valor_retorno = '' THEN
				EXECUTE 'select count(id) from cxp_prov where correo_electronico='''||str_data[24]||''' AND empresa_id='||emp_id||';' INTO valida_integridad;
				IF valida_integridad > 0 THEN
					valor_retorno := ''||valor_retorno||'email:El Correo Electrónico ingresado ya se encuentra en uso___';
				END IF;
			END IF;
		END IF;
	END IF; --TERMINA VALIDACION Catalogo de proveedores


	--INICIA VALIDACION Catalogo de empleados
	IF id_app=4 THEN
		--RAISE EXCEPTION '%',str_data[12]||' '||str_data[13]||' '||str_data[14]||' '||str_data[15]||' '||str_data[16]||' '||str_data[17];
		--SELECT INTO str_data string_to_array(''||campos_data||'','___');
		--nombre, 
		--RAISE EXCEPTION '%',str_data[3]; 
		EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_NombreCorrect'';' INTO mask_general;
		EXECUTE 'select '''||str_data[5]||''' ~ '''||mask_general||''';' INTO match_cadena;
		IF match_cadena = false THEN
			valor_retorno := 'nombre:Nombre No Valido___';
		END IF;
		
		--apellido paterno
		EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_ApellidopaternoCorrect'';' INTO mask_general;
		EXECUTE 'select '''||str_data[6]||''' ~ '''||mask_general||''';' INTO match_cadena;
		IF match_cadena = false THEN
			valor_retorno := 'apellidopaterno:Apellido paterno No Valido___';
		END IF;
		
		--apellido materno, 
		EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_ApellidomaternoCorrect'';' INTO mask_general;
		EXECUTE 'select '''||str_data[7]||''' ~ '''||mask_general||''';' INTO match_cadena;
		IF match_cadena = false THEN
			valor_retorno := 'apellidomaterno:Apellido materno No Valido___';
		END IF;
		
		--imss
		IF trim(str_data[8])<>'' THEN 
			EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_ImssCorrect'';' INTO mask_general;
			EXECUTE 'select '''||str_data[8]||''' ~ '''||mask_general||''';' INTO match_cadena;
			IF match_cadena = false THEN
				valor_retorno := ''||valor_retorno||'imss:No.IMSS No Valido. Debe ser 11 digitos___';
			END IF;
		END IF;
		
		--infonavit
		IF trim(str_data[9])<>'' THEN 
			EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_InfonavitCorrect'';' INTO mask_general;
			EXECUTE 'select '''||str_data[9]||''' ~ '''||mask_general||''';' INTO match_cadena;
			IF match_cadena = false THEN
				valor_retorno := ''||valor_retorno||'infonavit:Numero de Infonavit No Valido___';
			END IF;
		END IF;
		
		--curp
		IF incluye_nomina THEN 
			EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_CurpCorrect'';' INTO mask_general;
			EXECUTE 'select '''||str_data[10]||''' ~ '''||mask_general||''';' INTO match_cadena;
			IF match_cadena = false THEN
				valor_retorno := ''||valor_retorno||'curp:Curp No Valido___';
			END IF;
		ELSE
			IF trim(str_data[10])<>'' THEN 
				EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_CurpCorrect'';' INTO mask_general;
				EXECUTE 'select '''||str_data[10]||''' ~ '''||mask_general||''';' INTO match_cadena;
				IF match_cadena = false THEN
					valor_retorno := ''||valor_retorno||'curp:Curp No Valido___';
				END IF;
			END IF;
		END IF;
		
		--rfc
		IF incluye_nomina THEN 
			EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_RFCCorrect'';' INTO mask_general;
			EXECUTE 'select '''||str_data[11]||''' ~ '''||mask_general||''';' INTO match_cadena;
			IF match_cadena = false THEN
				valor_retorno := ''||valor_retorno||'rfc:RFC No Valido___';
			END IF;
		ELSE
			IF trim(str_data[11])<>'' THEN 
				EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_RFCCorrect'';' INTO mask_general;
				EXECUTE 'select '''||str_data[11]||''' ~ '''||mask_general||''';' INTO match_cadena;
				IF match_cadena = false THEN
					valor_retorno := ''||valor_retorno||'rfc:RFC No Valido___';
				END IF;
			END IF;
		END IF;
		
		--fecha nacimiento
		--IF str_data[12]!='' AND str_data[12]!=' ' THEN 
			EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_FechaNacIngCorrect'';' INTO mask_general;
			EXECUTE 'select '''||str_data[12]||''' ~ '''||mask_general||''';' INTO match_cadena;
			IF match_cadena = false THEN
				valor_retorno := ''||valor_retorno||'fechanacimiento:La fecha ingresada  No Valida___';
			END IF;
		--END IF;
		
		--fecha ingreso
		IF incluye_nomina THEN 
			EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_FechaNacIngCorrect'';' INTO mask_general;
			EXECUTE 'select '''||str_data[13]||''' ~ '''||mask_general||''';' INTO match_cadena;
			IF match_cadena = false THEN
				valor_retorno := ''||valor_retorno||'fechaingreso:La fecha ingresada no es valida___';
			END IF;
		ELSE
			IF trim(str_data[13])<>'' THEN 
				EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_FechaNacIngCorrect'';' INTO mask_general;
				EXECUTE 'select '''||str_data[13]||''' ~ '''||mask_general||''';' INTO match_cadena;
				IF match_cadena = false THEN
					valor_retorno := ''||valor_retorno||'fechaingreso:La fecha ingresada no es valida___';
				END IF;
			END IF;
		END IF;
		
		--escolaridad
		IF str_data[14]::integer =0 THEN
			valor_retorno := ''||valor_retorno||'escolaridad:La Escolaridad  NO es valida___';
		END IF;
		
		--sexo
		IF str_data[15]::integer= 0 THEN
			valor_retorno := ''||valor_retorno||'genero:El Genero NO es valido___';
		END IF;
		
		--edo civil
		IF str_data[16]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'civil:El estado civil NO es valido___';
		END IF;
	
		--puesto
		IF str_data[33]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'puesto:El Puesto no es valido. Debe ser 10 digitos___';
		END IF;
		
		--sucursal
		IF str_data[34]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'sucursal:Debe ingresar una Sucursal___';
		END IF;

		--Nombre de usuario
		IF trim(str_data[37])<>'' THEN
			EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_UserCorrect'';' INTO mask_general;
			EXECUTE 'select '''||str_data[37]||''' ~ '''||mask_general||''';' INTO match_cadena;
			IF match_cadena = false THEN
				valor_retorno := ''||valor_retorno||'email_usr:Introduzca un email de usuario___';
			END IF;
		END IF;
		
		--password
		--RAISE EXCEPTION '%',str_data[38];
		IF trim(str_data[37])<>'' THEN
			--Si existe nombre de usuario hay que validar que exista la contraseña
			EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_PasswordCorrect'';' INTO mask_general;
			EXECUTE 'select '''||str_data[38]||''' ~ '''||mask_general||''';' INTO match_cadena;
			IF match_cadena= false THEN
				valor_retorno := ''||valor_retorno||'password:Debe introducir una contraseña___';
			END IF;
		END IF;
		--RAISE EXCEPTION '%','arreglo: '||arreglo[1];
		--telefono
		IF trim(str_data[18])<>'' THEN
			EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_PhoneCorrect'';' INTO mask_general;
			EXECUTE 'select '''||str_data[18]||''' ~ '''||mask_general||''';' INTO match_cadena;
			IF match_cadena = false THEN
				valor_retorno := ''||valor_retorno||'telefono:El numero telefonico no es valido. Debe ser 10 digitos___';
			END IF;
		END IF;
		
		--pais
		IF str_data[21]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'pais:Pais No Valido___';
		END IF;

		--estado
		IF str_data[22]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'estado:Estado No Valido___';
		END IF;
		
		--municipio
		IF str_data[23]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'municipio:Municipio No Valido___';
		END IF;

		--calle
		IF str_data[24]!='' AND str_data[24]!=' ' THEN
			EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_CalleCorrect'';' INTO mask_general;
			EXECUTE 'select '''||str_data[24]||''' ~ '''||mask_general||''';' INTO match_cadena;
			IF match_cadena = false THEN
				valor_retorno := ''||valor_retorno||'calle:Calle No Valida___';
			END IF;
		END IF;
		
		--numero
		IF str_data[25]!='' AND str_data[25]!=' ' THEN
			IF str_data[25]!='' AND str_data[25]!=' ' THEN
				EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_AddressNumberCorrect'';' INTO mask_general;
				EXECUTE 'select '''||str_data[25]||''' ~ '''||mask_general||''';' INTO match_cadena;
				IF match_cadena = false THEN
					valor_retorno := ''||valor_retorno||'numero:Numero No Valido___';
				END IF;
			END IF;
		END IF;
		
		--colonia
		IF trim(str_data[26])<>'' THEN
			EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_ColoniaCorrect'';' INTO mask_general;
			EXECUTE 'select '''||str_data[26]||''' ~ '''||mask_general||''';' INTO match_cadena;
			IF match_cadena = false THEN
				valor_retorno := ''||valor_retorno||'colonia:Colonia No Valido___';
			END IF;
		END IF;
		
		--cp
		IF trim(str_data[27])<>'' THEN
			EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_CpCorrect'';' INTO mask_general;
			EXECUTE 'select '''||str_data[27]||''' ~ '''||mask_general||''';' INTO match_cadena;
			IF match_cadena = false THEN
				valor_retorno := ''||valor_retorno||'cp:CP No Valido___';
			END IF;
		END IF;
		
		--telefono emergencia
		IF trim(str_data[29])<>'' THEN 
			EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_PhoneCorrect'';' INTO mask_general;
			EXECUTE 'select '''||str_data[29]||''' ~ '''||mask_general||''';' INTO match_cadena;
			IF match_cadena = false THEN
				valor_retorno := ''||valor_retorno||'tcontacto:Telefono No Valido. Debe tener al menos 10 digitos___';
			END IF;
		END IF;

		IF incluye_nomina THEN 
			--Aqui solo entra si incluye nomina
			--no_int,--str_data[54],
			
			--str_data[55]::integer Regimen de Contratacion
			IF str_data[55]::integer=0 THEN
				valor_retorno := ''||valor_retorno||'regimencontratacio:Es necesario seleccionar el Regimen de Contratacion.___';
			END IF;
			
			--str_data[56]::integer Tipo de Contrato
			--str_data[57]::integer Tipo de Jornada
			--str_data[58]::integer Periodicidad del Pago
			--str_data[59]::integer Banco
			--str_data[60]::integer Rieso del Puesto
			--str_data[61]::double precision Salario Base
			--str_data[62]::double precision Salario Integrado
			--str_data[63] Registro Patronal
			--str_data[64] Clave
			
			
			--str_data[65] Percepciones
			IF trim(str_data[65])='' THEN
				valor_retorno := ''||valor_retorno||'percep:Es necesario seleccionar por lo menos un concepto de Percepcion.___';
			END IF;
			
			--str_data[66] deducciones
			IF trim(str_data[66])='' THEN
				valor_retorno := ''||valor_retorno||'deduc:Es necesario seleccionar por lo menos un concepto de Deduccion.___';
			END IF;
		END IF;
		
		
		IF str_data[1] = '0' THEN
			IF trim(str_data[10])<>'' THEN 
				EXECUTE 'select count(id) from gral_empleados where borrado_logico=false and gral_emp_id='||emp_id||' and curp ilike '''||str_data[10]||''';' INTO valida_integridad;
				--RAISE EXCEPTION '%',valida_integridad;
				IF valida_integridad > 0 THEN
					valor_retorno := ''||valor_retorno||'curp:La curp ingresada ya se encuentra en uso___';
				END IF;
			END IF;
			
			valida_integridad:=0;

			IF trim(str_data[11])<>'' THEN 
				EXECUTE 'select count(id) from gral_empleados where borrado_logico=false and gral_emp_id='||emp_id||' and rfc ilike '''||str_data[11]||''';' INTO valida_integridad;
				IF valida_integridad > 0 THEN
					valor_retorno := ''||valor_retorno||'rfc:El RFC ingresado ya se encuentra en uso___';
				END IF;
			END IF;
			
			valida_integridad:=0;
			IF trim(str_data[37])<>'' THEN 
				EXECUTE 'select count(id) from gral_usr where titulo ilike '''||str_data[37]||''';' INTO valida_integridad;
				IF valida_integridad > 0 THEN
					valor_retorno := ''||valor_retorno||'email_usr:El usuario ingresado ya se encuentra en uso.___';
				END IF;
			END IF;
			
			IF trim(str_data[37])<>'' THEN
				--Si existe el nombre del usuario hay que validar la verificacion del Password
				valida_integridad:=0;
				IF str_data[38] <> str_data[39] THEN
					valor_retorno := ''||valor_retorno||'verificapass:La verificacion del password no coincide con la primera.___';
				END IF;
			END IF;

		END IF;
	END IF; --TERMINA VALIDACION Catalogo de empleados


	-- INICIA VALIDACION Catalogo de Clientes
	IF id_app=5 THEN
		
		--rfc
		EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_RFCCorrect'';' INTO mask_general;
		EXECUTE 'select '''||str_data[6]||''' ~ '''||mask_general||''';' INTO match_cadena;
		IF match_cadena = false THEN
			valor_retorno := ''||valor_retorno||'rfc:El RFC ingresado NO es valido___';
		END IF;
		
		--curp
		IF str_data[7]!='' THEN
			EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_CurpCorrect'';' INTO mask_general;
			EXECUTE 'select '''||str_data[7]||''' ~ '''||mask_general||''';' INTO match_cadena;
			IF match_cadena = false THEN
				valor_retorno := ''||valor_retorno||'curp:La curp ingresada no es valida___';
			END IF;
		END IF;

		--razon social
		EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_RazonsocialCorrect'';' INTO mask_general;
		EXECUTE 'select '''||str_data[8]||''' ~ '''||mask_general||''';' INTO match_cadena;
		IF match_cadena = false THEN
			valor_retorno := 'razonsocial:Razon social no No Valido___';
		END IF;
		
		--clave comercial
		IF str_data[9] = '' OR str_data[9] = ' ' THEN
			valor_retorno := ''||valor_retorno||'clavecomercial:La Clave Comercial es incorrecta___';
		END IF;
		
		--calle
		EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_CalleCorrect'';' INTO mask_general;
		EXECUTE 'select '''||str_data[10]||''' ~ '''||mask_general||''';' INTO match_cadena;
		IF match_cadena = false THEN
			valor_retorno := ''||valor_retorno||'calle:Calle No Valida___';
		END IF;
		
		--num calle
		EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_AddressNumberCorrect'';' INTO mask_general;
		EXECUTE 'select '''||str_data[11]||''' ~ '''||mask_general||''';' INTO match_cadena;
		IF match_cadena = false THEN
			valor_retorno := ''||valor_retorno||'numeroint:Numero de Calle No Valida___';
		END IF;

		
		--colonia
		EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_ColoniaCorrect'';' INTO mask_general;
		EXECUTE 'select '''||str_data[14]||''' ~ '''||mask_general||''';' INTO match_cadena;
		IF match_cadena = false THEN
			valor_retorno := ''||valor_retorno||'colonia:Colonia No Valido___';
		END IF;
		
		--codigo postal
		EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_CpCorrect'';' INTO mask_general;
		EXECUTE 'select '''||str_data[15]||''' ~ '''||mask_general||''';' INTO match_cadena;
		IF match_cadena = false THEN
			valor_retorno := ''||valor_retorno||'cp:Codigo postal No Valido___';
		END IF;
		
		--pais
		IF str_data[16]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'pais:Es necesario seleccionar el Pais del Cliente___';
		END IF;
		
		--estado
		IF str_data[17]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'estado:Es necesario seleccionar el Estado del Cliente___';
		END IF;
		
		--municipio
		IF str_data[18]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'municipio:Es necesario seleccionar el Municipio del Cliente___';
		END IF;
		
		--telefono 1
		IF trim(str_data[6])<>'XEXX010101000' THEN 
			IF str_data[20]='' OR str_data[20]=' ' THEN
				valor_retorno := ''||valor_retorno||'tel1:Es necesario ingresar el numero de Teléfono___';
			ELSE
				--telefono
				EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_PhoneCorrect'';' INTO mask_general;
				EXECUTE 'select '''||str_data[20]||''' ~ '''||mask_general||''';' INTO match_cadena;
				IF match_cadena = false THEN
					valor_retorno := ''||valor_retorno||'tel1:El numero telefonico no es valido. Debe ser de 10 digitos___';
				END IF;
			END IF;
		END IF;
		
		--FAX, utiliza la misma mascara que telefono
		IF str_data[22]!='' THEN
			EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_PhoneCorrect'';' INTO mask_general;
			EXECUTE 'select '''||str_data[22]||''' ~ '''||mask_general||''';' INTO match_cadena;
			IF match_cadena = false THEN
				valor_retorno := ''||valor_retorno||'fax:El numero de Fax no es valido. Debe ser 10 digitos___';
			END IF;
		END IF;
	

		--email
		IF str_data[25]!='' THEN
			EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_CorreoCorrect'';' INTO mask_general;
			EXECUTE 'select '''||str_data[25]||''' ~ '''||mask_general||''';' INTO match_cadena;
			IF match_cadena = false THEN
				valor_retorno := ''||valor_retorno||'email:Correo No Valido___';
			END IF;
		END IF;
		
		--str_data[26] id agente
		IF str_data[26] = '0' THEN
			valor_retorno := ''||valor_retorno||'agente:Es necesario selecionar un Agente de Ventas para el cliente___';
		END IF;

		--zona
		IF str_data[28] = '0' THEN
			valor_retorno := ''||valor_retorno||'zona:Es necesario selecionar una Zona para el cliente___';
		END IF;

		--grupo
		IF str_data[29] = '0' THEN
			valor_retorno := ''||valor_retorno||'grupo:Es necesario selecionar un Grupo para el cliente___';
		END IF;

		--tipo CLIENTE
		IF str_data[30] = '0' THEN
			valor_retorno := ''||valor_retorno||'tipocliente:Es necesario selecionar el tipo de cliente___';
		END IF;

		--clasificacion 1
		IF str_data[31] = '0' THEN
			valor_retorno := ''||valor_retorno||'clasif1:Es necesario selecionar una Clasificacion para el cliente___';
		END IF;

		--clasificacion 2
		IF str_data[32] = '0' THEN
			valor_retorno := ''||valor_retorno||'clasif2:Es necesario selecionar una Clasificacion para el cliente___';
		END IF;

		--clasificacion 3
		IF str_data[33] = '0' THEN
			valor_retorno := ''||valor_retorno||'clasif3:Es necesario selecionar una Clasificacion para el cliente___';
		END IF;

		--moneda
		IF str_data[34] = '0' THEN
			valor_retorno := ''||valor_retorno||'moneda:Es necesario selecionar una Moneda para el cliente___';
		END IF;

		IF str_data[39] = '0' THEN
			valor_retorno := ''||valor_retorno||'diascredito:Es necesario selecionar los dias de Credito para el cliente___';
		END IF;
		
		--inicio de credito
		IF str_data[41]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'inicred:Es necesario seleccionar el Inicio del Crédito___';
		END IF;
		
		--e-mail contacto compras
		IF str_data[61] != '' AND str_data[61] != ' ' THEN
			EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_CorreoCorrect'';' INTO mask_general;
			EXECUTE 'select '''||str_data[61]||''' ~ '''||mask_general||''';' INTO match_cadena;
			IF match_cadena = false THEN
				valor_retorno := ''||valor_retorno||'cemail:E-mail del Contacto No Valido___';
			END IF;
		END IF;
		
		--e-mail contacto pagos
		IF str_data[77] != '' AND str_data[77] != ' ' THEN
			EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_CorreoCorrect'';' INTO mask_general;
			EXECUTE 'select '''||str_data[77]||''' ~ '''||mask_general||''';' INTO match_cadena;
			IF match_cadena = false THEN
				valor_retorno := ''||valor_retorno||'pemail:E-mail del Contacto No Valido___';
			END IF;
		END IF;
		
		
		IF str_data[78]::boolean=true THEN
			IF str_data[79]='' OR str_data[79]=' ' THEN
				valor_retorno := ''||valor_retorno||'retimmex:Es necesario ingresar la Tasa de Retenci&oacute;n IMMEX.___';
			ELSE
				IF str_data[79]::double precision > 100 THEN
					valor_retorno := ''||valor_retorno||'retimmex:La Tasa de Retenci&oacute;n IMMEX debe ser menor o igual a 100%.___';
				END IF;
				IF str_data[79]::double precision < 1 THEN
					valor_retorno := ''||valor_retorno||'retimmex:La Tasa de Retenci&oacute;n IMMEX debe ser mayor o igual a 1%.___';
				END IF;
			END IF;
		END IF;
		
		
		IF validaListaPrecioCliente THEN 
			--str_data[89] 	select_lista de precio
			IF str_data[89]='0' THEN
				valor_retorno := ''||valor_retorno||'lp:Es necesario seleccionar una Lista de Precio para el Cliente___';
			END IF;
		END IF;
		
		--str_data[90] 	select_metodo_pago
		IF str_data[90]='0' THEN
			valor_retorno := ''||valor_retorno||'metodopago:Es necesario seleccionar un M&eacute;todo de Pago para el Cliente___';
		END IF;
		
		IF str_data[4] = '0' THEN

			valida_integridad:=0;
			IF trim(str_data[6])<>'XEXX010101000' THEN 
				EXECUTE 'select count(id) from cxc_clie where rfc ilike '''||str_data[6]||''' AND borrado_logico=false AND empresa_id='||emp_id||';' INTO valida_integridad;
				IF valida_integridad > 0 THEN
					valor_retorno := ''||valor_retorno||'rfc:El RFC ingresado ya se encuentra en uso.___';
				END IF;
			END IF;
			
			valida_integridad:=0;
			EXECUTE 'select count(id) from cxc_clie where razon_social ilike '''||str_data[8]||''' AND borrado_logico=false AND empresa_id='||emp_id||';' INTO valida_integridad;
			IF valida_integridad > 0 THEN
				valor_retorno := ''||valor_retorno||'razonsocial:La razon social ingresada ya se encuentra en uso___';
			END IF;
			
			valida_integridad:=0;
			EXECUTE 'select count(id) from cxc_clie where clave_comercial ilike '''||str_data[9]||''' AND borrado_logico=false AND empresa_id='||emp_id||';' INTO valida_integridad;
			IF valida_integridad > 0 THEN
				valor_retorno := ''||valor_retorno||'clavecomercial:La Clave Comercial ingresada ya se encuentra en uso___';
			END IF;

		END IF;
	END IF; --TERMINA VALIDACION validacion de clientes


	-- INICIAA VALIDACION de Productos
	IF id_app=8 THEN

		--query para verificar si la Empresa actual incluye Modulo de Produccion
		SELECT incluye_produccion, control_exis_pres FROM gral_emp WHERE id=emp_id INTO incluye_modulo_produccion, controlExisPres;
		
		--codigo producto,--str_data[31]
		IF str_data[31]='' OR str_data[31]=' ' THEN
			valor_retorno := ''||valor_retorno||'codigo:Es necesario C&oacute;digo del Producto.___';
		END IF;
		
		--descripcion,--str_data[5]
		EXECUTE 'select mask_regex from erp_mascaras_para_validaciones_por_app where app_id='||id_app||' and mask_name ilike ''is_TituloenCorrect'';' INTO mask_general;
		EXECUTE 'select '''||str_data[5]||''' ~ '''||mask_general||''';' INTO match_cadena;
		IF match_cadena = false THEN
			valor_retorno := ''||valor_retorno||'descripcion:La Descripcion igresada no es valida___';
		END IF;
		
		--tipo_de_producto_id,--str_data[18]::integer
		IF str_data[18]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'prodtipo:Es necesario seleccionar el Tipo de Producto.___';
		END IF;
		
		--str_data[20] 	unidad
		IF str_data[20]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'unidad:Es necesario seleccionar la Unidad de Mendida para el Producto.___';
		END IF;
		
		--Si el tiopo de producto es diferente de 3 y 4, hay que validar
		--tipo=3 Kit
		--tipo=4 Servicios
		IF str_data[18]::integer<>3 AND str_data[18]::integer<>4 THEN
			--inv_clas_id,--str_data[8]::integer
			IF str_data[8]::integer = 0 THEN
				valor_retorno := ''||valor_retorno||'clase:Clasificaci&oacute;n no valida.___';
			END IF;
			
			--inv_stock_clasif_id,--str_data[9]::integer
			IF str_data[9]::integer = 0 THEN
				valor_retorno := ''||valor_retorno||'stock:Es necesario seleecionar una Clasificaci&oacute;n de Stock.___';
			END IF;
			
			--inv_prod_familia_id,--str_data[11]::integer
			--IF str_data[11]::integer = 0 THEN
			--	valor_retorno := ''||valor_retorno||'familia:Es necesario seleccionar una Familia para el Producto.___';
			--END IF;
			
			--subfamilia_id,--str_data[12]::integer
			--IF str_data[12]::integer = 0 THEN
			--	valor_retorno := ''||valor_retorno||'subfamilia:Es necesario seleccionar una Subfamilia para el Producto.___';
			--END IF;
			
			--inv_prod_grupo_id,--str_data[13]::integer
			IF str_data[13]::integer = 0 THEN
				valor_retorno := ''||valor_retorno||'grupo:Es necesario seleccionar un Grupo para el Producto.___';
			END IF;
			
			/*
			--meta_impuesto,--str_data[15]::integer
			IF str_data[15]::integer = 0 THEN
				valor_retorno := ''||valor_retorno||'iva:Es necesario seleccionar el Impuesto para el Producto.___';
			END IF;
			*/
			--inv_prod_linea_id,--str_data[16]::integer
			IF str_data[16]::integer = 0 THEN
				valor_retorno := ''||valor_retorno||'linea:Es necesario seleccionar la L&iacute;nea para el Producto.___';
			END IF;
			
			--inv_mar_id,--str_data[17]::integer
			IF str_data[17]::integer = 0 THEN
				valor_retorno := ''||valor_retorno||'marca:Es necesario seleccionar la Marca para el Producto.___';
			END IF;
			
			--inv_seccion_id,--str_data[19]::integer
			IF str_data[19]::integer = 0 THEN
				valor_retorno := ''||valor_retorno||'seccion:Es necesario seleccionar la Secci&oacute;n para el Producto.___';
			END IF;
			
			--str_data[28] 	presentaciones del producto
			IF trim(str_data[28]) = '' THEN
				valor_retorno := ''||valor_retorno||'seleccionados:Es necesario seleccionar al menos una Presentaci&oacute;n para el Producto___';
			END IF;
			
			IF str_data[30]::double precision = 0 then 
				valor_retorno := ''|| valor_retorno||'densidad:Densidad debe ser mayor que 0___';
			END IF;
		END IF;
		
		--Presentacion Default--str_data[42]::integer
		IF str_data[42]::integer = 0 THEN
			valor_retorno := ''||valor_retorno||'presdefault:Es necesario seleccionar la Presentaci&oacute;n Default.___';
		END IF;
		
		IF str_data[4] = '0' THEN
			IF str_data[31]!='' AND str_data[31]!=' ' THEN
				EXECUTE 'SELECT count(id) FROM inv_prod WHERE sku='''||str_data[31]||''' AND borrado_logico=FALSE  AND empresa_id='||emp_id||';' INTO valida_integridad;
				IF valida_integridad > 0 THEN
					valor_retorno := ''||valor_retorno||'codigo:El C&oacute;digo del Producto ya se encuentra registrado.___';
				END IF;
			END IF;
			
			IF str_data[5] != '' THEN
				EXECUTE 'SELECT count(id) FROM inv_prod WHERE descripcion = '''||str_data[5]||''' AND borrado_logico=FALSE  AND empresa_id='||emp_id||';' INTO valida_integridad;
				IF valida_integridad > 0 THEN
					valor_retorno := ''||valor_retorno||'descripcion:La Descripci&oacute;n Ingresada ya se encuentra en uso.___';
				END IF;
			END IF;
						
		ELSE
			EXECUTE 'SELECT sku, id FROM inv_prod WHERE sku='''||str_data[31]||''' AND borrado_logico=FALSE  AND empresa_id='||emp_id||';' INTO titulo_mask, valida_integridad;
			IF str_data[4]::integer != valida_integridad THEN
				valor_retorno := ''||valor_retorno||'codigo:El C&oacute;digo del Producto ya se encuentra registrado.___';
			END IF;


			--RAISE EXCEPTION '%','controlExisPres: '||controlExisPres;
			--Verificar si hay que validar existencias de Presentaciones
			IF controlExisPres=true THEN 
				IF str_data[18]::integer<>3 AND str_data[18]::integer<>4 THEN
					IF trim(str_data[28]) <> '' THEN
						--convertir en arreglo los id de presentaciones de producto
						SELECT INTO str_filas2 string_to_array(str_data[28],',');
						
						--obtiene numero de elementos del arreglo str_pres
						total_filas2:= array_length(str_filas2,1);
						
						sql_select:='
						SELECT 
							presentacion_id,
							presentacion,
							sum(existencia) AS existencia
						FROM (
							SELECT 
								inv_prod_pres_x_prod.presentacion_id,
								inv_prod_presentaciones.titulo  AS presentacion,
								inv_exi_pres.inv_alm_id,
								(inv_exi_pres.inicial + inv_exi_pres.entradas - inv_exi_pres.reservado - inv_exi_pres.salidas) AS existencia
							FROM inv_prod_pres_x_prod 
							JOIN inv_exi_pres ON (inv_exi_pres.inv_prod_id=inv_prod_pres_x_prod.producto_id AND inv_exi_pres.inv_prod_presentacion_id=inv_prod_pres_x_prod.presentacion_id)
							JOIN inv_prod_presentaciones ON inv_prod_presentaciones.id=inv_prod_pres_x_prod.presentacion_id
							WHERE inv_prod_pres_x_prod.producto_id='||str_data[4]::integer||' 
						) AS sbt WHERE existencia>0
						GROUP BY presentacion_id, presentacion';

						--En esta cadena se almacenan las presentaciones que fueron eliminados y que tienen existencia
						cadena := '';
						
						FOR record1 IN EXECUTE(sql_select) LOOP
							exis:=0;
							cont_fila2:=1;
							FOR cont_fila2 IN 1 .. total_filas2 LOOP
								IF record1.presentacion_id=str_filas2[cont_fila2]::integer THEN 
									exis:= exis + 1;
								END IF;
							END LOOP;
							
							IF exis=0 THEN 
								cadena := cadena || record1.presentacion||',';
							END IF;
						END LOOP;
						
						IF trim(cadena)<>'' THEN
							valor_retorno := ''||valor_retorno||'seleccionados:Estas presentaciones('||cadena||') no se Pueden eliminar, tienen existencia.___';
						END IF;
						
					END IF;
				END IF;
			END IF;

		END IF;
	END IF;--TERMINA VALIDACION validacion de productos


	--Validacion de Catalogo Percepciones
        IF id_app=170 THEN
                --str_data[4]   id
		--str_data clave nuevo_folio
		--str_data[5]	titulo
		--str_data[6]	activo
		--str_data[7]	tipopercepciones
                               
		--titulo
		IF trim(str_data[5]) = '' THEN
			valor_retorno := ''||valor_retorno||'titulo:Es necesario ingresar un Titulo a la Percepci&oacute;n.___';
		END IF;

           
                --tipopercepciones
		IF str_data[7]::integer =0 THEN
			valor_retorno := ''||valor_retorno||'percepcion:Es necesario seleccionar un tipo de Percepci&oacute;n.___';
		END IF;
		
		IF str_data[4] = '0' THEN
			--titulo
			IF str_data[5] != '' THEN
				EXECUTE 'SELECT count(id) FROM nom_percep WHERE titulo = '''||str_data[5]||''' AND borrado_logico=FALSE  AND gral_emp_id='||emp_id||';' INTO valida_integridad;
				IF valida_integridad > 0 THEN
					valor_retorno := ''||valor_retorno||'titulo:El Titulo de la Percepci&oacute;n ya se encuentra registrada.___';
				END IF;
			END IF;
		ELSE
			EXECUTE 'SELECT titulo, id FROM nom_percep WHERE titulo='''||str_data[5]||''' AND borrado_logico=FALSE  AND gral_emp_id='||emp_id||';' INTO titulo_mask, valida_integridad;
			IF str_data[4]::integer != valida_integridad THEN
				valor_retorno := ''||valor_retorno||'titulo:El Titulo de la Percepci&oacute;n ya se encuentra registrada.___';
			END IF;
		END IF;
                        
        END IF;--Termina Validacion Catalogo Percepciones


        --Validacion de Catalogo Deducciones
        IF id_app=171 THEN
                --str_data[4]   id
		--str_data clave nuevo_folio
		--str_data[5]	titulo
		--str_data[6]	activo
		--str_data[7]	tipodeducciones
		
                --titulo
		IF trim(str_data[5]) = '' THEN
			valor_retorno := ''||valor_retorno||'titulo:Es necesario ingresar un Titulo a la Deducci&oacute;n.___';
		END IF;

           
                --tipodeducciones
		IF str_data[7]::integer =0 THEN
			valor_retorno := ''||valor_retorno||'deduccion:Es necesario seleccionar un tipo de Deducci&oacute;n.___';
		END IF;
		
		IF str_data[4] = '0' THEN
			--titulo
			IF str_data[5] != '' THEN
				EXECUTE 'SELECT count(id) FROM nom_deduc WHERE titulo = '''||str_data[5]||''' AND borrado_logico=FALSE  AND gral_emp_id='||emp_id||';' INTO valida_integridad;
				IF valida_integridad > 0 THEN
					valor_retorno := ''||valor_retorno||'titulo:El Titulo de la Percepci&oacute;n ya se encuentra registrada.___';
				END IF;
			END IF;
			--titulo			
		ELSE
			EXECUTE 'SELECT titulo, id FROM nom_deduc WHERE titulo='''||str_data[5]||''' AND borrado_logico=FALSE  AND gral_emp_id='||emp_id||';' INTO titulo_mask, valida_integridad;
			IF str_data[4]::integer != valida_integridad THEN
				valor_retorno := ''||valor_retorno||'titulo:El Titulo de la Percepci&oacute;n ya se encuentra registrada.___';
			END IF;
		END IF;
                        
        END IF;
        --Termina Validacion Catalogo Deducciones

	
	
	--validacion de Catalogo Periodicidad de Pago
        IF id_app=172 THEN
                --str_data[4]  id
                --str_data[5]  titulo 
                --str_data[6]  no_periodos
		--str_data[7]  activo
		
                 --titulo
		IF trim(str_data[5]) = '' THEN
			valor_retorno := ''||valor_retorno||'titulo:Es necesario ingresar el Titulo de la Periodicidad de Pago.___';
		END IF;
		
		--no_periodos
		IF trim(str_data[6]) = '' THEN
			valor_retorno := ''||valor_retorno||'periodos:Es necesario ingresar el N&uacute;mero del Peridodo.___';
		END IF;
		
		IF str_data[4] = '0' THEN
			--no_periodos
			IF str_data[6]!='' AND str_data[6]!=' ' THEN
				
			EXECUTE 'SELECT count(id) FROM nom_periodicidad_pago WHERE no_periodos = '''||str_data[6]::integer||''' AND borrado_logico=FALSE  AND gral_emp_id='||emp_id||';' INTO valida_integridad;
				IF valida_integridad > 0 THEN
					valor_retorno := ''||valor_retorno||'periodos:El N&uacute;mero del Periodo ya se encuentra registrada.___'; 
				END IF;
			END IF;
			
			--titulo
			IF str_data[5] != '' THEN

			EXECUTE 'SELECT count(id) FROM nom_periodicidad_pago WHERE titulo='''||str_data[5]||''' AND borrado_logico=FALSE  AND gral_emp_id='||emp_id||';' INTO valida_integridad;
				IF valida_integridad > 0 THEN
					valor_retorno := ''||valor_retorno||'titulo:El Titulo de la Periodicidad de Pago ya se encuentra registrada.___';
				
				END IF;
			END IF;
			--titulo			
		ELSE
			EXECUTE 'SELECT titulo, id FROM nom_periodicidad_pago WHERE titulo='''||str_data[5]||''' AND borrado_logico=FALSE  AND gral_emp_id='||emp_id||';' INTO titulo_mask, valida_integridad;
			IF str_data[4]::integer != valida_integridad THEN
				valor_retorno := ''||valor_retorno||'titulo:El Titulo de la Periodicidad de Pago ya se encuentra registrada.___';
			END IF;
			--no_periodos
			EXECUTE 'SELECT no_periodos, id FROM nom_periodicidad_pago WHERE no_periodos='''||str_data[6]::integer||''' AND borrado_logico=FALSE  AND gral_emp_id='||emp_id||';' INTO titulo_mask, valida_integridad;
			IF str_data[4]::integer != valida_integridad THEN
				valor_retorno := ''||valor_retorno||'periodos:El N&uacute;mero del Periodo ya se encuentra registrada.___';
			END IF;
		END IF;
        END IF;
        --Termina validacion Periodicidad de Pago



	
	--Validacion de Facturacion de Nomina
        IF id_app=173 THEN
		IF command_selected='new' OR command_selected='edit' THEN 
			--str_data[1]	app_selected
			--str_data[2]	command_selected
			--str_data[3]	id_usuario
			--str_data[4]	identificador
			--str_data[5]	comp_tipo
			--str_data[6]	comp_forma_pago
			--str_data[7]	comp_tc
			--str_data[8]	comp_no_cuenta
			--str_data[9]	fecha_pago
			--str_data[10]	select_comp_metodo_pago
			--str_data[11]	select_comp_moneda
			--str_data[12]	select_comp_periodicidad
			--str_data[13]	select_no_periodo


			 --str_data[5]	comp_tipo
			IF trim(str_data[5]) = '' THEN
				valor_retorno := ''||valor_retorno||'comptipo: Se requiere el Tipo de Comprobante.___';
			END IF;
			
			--str_data[6]	comp_forma_pago
			IF trim(str_data[6]) = '' THEN
				valor_retorno := ''||valor_retorno||'compformapago:Se requiere la Forma de Pago.___';
			END IF;
			
			--str_data[9]	fecha_pago
			IF trim(str_data[9]) = '' THEN
				valor_retorno := ''||valor_retorno||'compfechapago:Se requiere la Fecha de Pago.___';
			END IF;

			--str_data[10]	select_comp_metodo_pago
			IF trim(str_data[10]) = '' THEN
				valor_retorno := ''||valor_retorno||'compmetodopago:Se requiere el Metodo de Pago.___';
			ELSE
				IF str_data[10]::integer = 0 THEN
					valor_retorno := ''||valor_retorno||'compmetodopago:Se requiere el Metodo de Pago.___';
				END IF;
			END IF;

			
			--str_data[11]	select_comp_moneda
			IF trim(str_data[11]) = '' THEN
				valor_retorno := ''||valor_retorno||'compmoneda:Se requiere la Moneda.___';
			ELSE
				IF str_data[11]::integer=0 THEN
					valor_retorno := ''||valor_retorno||'compmoneda:Se requiere la Moneda.___';
				END IF;
			END IF;
			
			--str_data[12]	select_comp_periodicidad 
			IF trim(str_data[12]) <> '' THEN
				IF str_data[12]::integer = 0 THEN
					valor_retorno := ''||valor_retorno||'compperiodicidad:Se requiere la Periodicidad de Pago.___';
				END IF;
			ELSE
				valor_retorno := ''||valor_retorno||'compperiodicidad:Se requiere la Periodicidad de Pago.___';
			END IF;
			
			
			
			IF str_data[4]='0' THEN
				--str_data[13]	select_no_periodo
				IF trim(str_data[13])<>'' AND trim(str_data[13])<>'0' THEN
					EXECUTE 'SELECT count(id) FROM fac_nomina WHERE nom_periodos_conf_det_id='||str_data[13]::integer||' AND gral_emp_id='||emp_id||';' INTO valida_integridad;
					IF valida_integridad > 0 THEN
						valor_retorno := ''||valor_retorno||'compnoperiodo:Ya existe una N&oacute;mina con el N&uacute;mero del Periodo seleccionado.___'; 
					END IF;
				END IF;
			ELSE
				
			END IF;

			
		END IF;




		
		IF command_selected='new_nomina' OR command_selected='edit_nomina' THEN 
			--str_data[1]	app_selected
			--str_data[2]	command_selected
			--str_data[3]	id_usuario
			--str_data[4]	identificador
			--str_data[5]	id_reg
			--str_data[6]	id_empleado
			IF trim(str_data[6])='' OR trim(str_data[6])='0'THEN
				valor_retorno := ''||valor_retorno||'noempleado:Se requiere seleccionar un empleado valido.___';
			END IF;
			
			--str_data[7]	no_empleado
			IF trim(str_data[7]) = '' THEN
				valor_retorno := ''||valor_retorno||'noempleado:Se requiere la Clave del Empleado.___';
			END IF;
			
			--str_data[8]	rfc_empleado
			IF trim(str_data[8]) = '' THEN
				valor_retorno := ''||valor_retorno||'rfcempleado:Se requiere el RFC del Empleado.___';
			ELSE
				EXECUTE 'select '''||str_data[8]||''' ~ ''^[A-Za-z0-9&]{3,4}[0-9]{6}[A-Za-z0-9]{3}$'';' INTO match_cadena;
				IF match_cadena = false THEN
					valor_retorno := ''||valor_retorno||'rfcempleado:RFC No Valido.___';
				END IF;
			END IF;
			
			--str_data[9]	nombre_empleado
			IF trim(str_data[9]) = '' THEN
				valor_retorno := ''||valor_retorno||'nombreempleado:Se requiere el Nombre completo del Empleado.___';
			END IF;
			
			--str_data[10]	select_departamento
			--str_data[11]	select_puesto
			--str_data[12]	fecha_contrato
			
			--str_data[13]	antiguedad
			IF trim(str_data[13]) = '' THEN
				valor_retorno := ''||valor_retorno||'antiguedad:Se requiere la Antig&uuml;edad en n&uacute;mero de semanas.___';
			ELSE
				IF str_data[13]::double precision<=0 THEN 
					valor_retorno := ''||valor_retorno||'antiguedad:La Antig&uuml;edad en n&uacute;mero de semanas debe ser mayor a cero.___';
				END IF;
			END IF;
			
			--str_data[14]	curp
			IF trim(str_data[14]) = '' THEN
				valor_retorno := ''||valor_retorno||'curp:Se requiere la CURP del Empleado.___';
			ELSE
				EXECUTE 'select '''||str_data[14]||''' ~ ''^[A-Za-z]{4}[0-9]{6}[A-Za-z]{6}[A-Za-z0-9]{1}[0-9]{1}$'';' INTO match_cadena;
				IF match_cadena = false THEN
					valor_retorno := ''||valor_retorno||'curp:Curp No Valido___';
				END IF;
			END IF;
			
			--str_data[15]	select_reg_contratacion
			IF str_data[15]::integer=0 THEN
				valor_retorno := ''||valor_retorno||'regimencontratacio:Se requiere el R&eacute;gimen de Contrataci&oacute;n del Empleado.___';
			END IF;
			
			--str_data[16]	select_tipo_contrato
			--str_data[17]	select_tipo_jornada
			--str_data[18]	select_preriodo_pago
			IF str_data[18]::integer=0 THEN
				valor_retorno := ''||valor_retorno||'periodicidadpago:Se requiere la Periodicidad del Pago.___';
			END IF;
			
			--str_data[19]	clabe
			--str_data[20]	select_banco
			--str_data[21]	select_riesgo_puesto
			--str_data[22]	imss
			--str_data[23]	reg_patronal
			--str_data[24]	salario_base
			--str_data[25]	fecha_ini_pago
			IF trim(str_data[25])='' THEN
				valor_retorno := ''||valor_retorno||'fechainipago:Se requiere Fecha Inicial del Periodo de Pago.___';
			END IF;
			
			--str_data[26]	fecha_fin_pago
			IF trim(str_data[26]) = '' THEN
				valor_retorno := ''||valor_retorno||'fechafinpago:Se requiere Fecha Final del Periodo de Pago.___';
			END IF;
			
			--str_data[27]	salario_integrado
			--str_data[28]	no_dias_pago
			IF trim(str_data[28])='' THEN
				valor_retorno := ''||valor_retorno||'nodiaspago:Se requiere el N&uacute;mero de D&iacute;as Pagados.___';
			ELSE
				IF str_data[28]::integer<=0 THEN
					valor_retorno := ''||valor_retorno||'nodiaspago:Se requiere el N&uacute;mero de D&iacute;as Pagados.___';
				END IF;
			END IF;
			
			--str_data[29]	concepto_descripcion
			IF trim(str_data[29]) = '' THEN
				valor_retorno := ''||valor_retorno||'grid__concepto_descripcion:Se requiere el Concepto para el Comprobante.___';
			END IF;
			
			--str_data[30]	concepto_unidad
			IF trim(str_data[30]) = '' THEN
				valor_retorno := ''||valor_retorno||'grid__concepto_unidad:Se requiere la Unidad.___';
			END IF;
			--str_data[31]	concepto_cantidad
			IF trim(str_data[31]) = '' THEN
				valor_retorno := ''||valor_retorno||'grid__concepto_cantidad:Se requiere la Cantidad.___';
			ELSE 
				IF str_data[31]::double precision <=0 THEN
					valor_retorno := ''||valor_retorno||'grid__concepto_cantidad:La Cantidad debe ser mayor a cero.___';
				END IF;
			END IF;
			--str_data[32]	concepto_valor_unitario
			IF trim(str_data[32]) = '' THEN
				valor_retorno := ''||valor_retorno||'grid__concepto_valor_unitario:Se requiere el Valor Unitario del Concepto.___';
			ELSE 
				IF str_data[32]::double precision <=0 THEN
					valor_retorno := ''||valor_retorno||'grid__concepto_valor_unitario:El Valor Unitario debe ser mayor a cero.___';
				END IF;
			END IF;
			
			--str_data[33]	concepto_importe
			IF trim(str_data[33]) = '' THEN
				valor_retorno := ''||valor_retorno||'grid__concepto_importe:Se requiere el Importe del Concepto.___';
			ELSE 
				IF str_data[33]::double precision <=0 THEN
					valor_retorno := ''||valor_retorno||'grid__concepto_importe:El Importe debe ser mayor a cero.___';
				END IF;
			END IF;
			
			--str_data[34]	descuento
			--str_data[35]	motivo_descuento
			--str_data[36]	select_impuesto_retencion
			IF str_data[36]::integer=0 THEN
				valor_retorno := ''||valor_retorno||'selectimpuestoret:Se requiere el impuesto de la retenci&oacute;n.___';
			END IF;
			--str_data[37]	importe_retencion
			IF trim(str_data[37]) = '' THEN
				valor_retorno := ''||valor_retorno||'importeisr:Se requiere el Monto de la Retenci&oacute;n.___';
			ELSE
				IF str_data[37]::double precision<=0 THEN
					valor_retorno := ''||valor_retorno||'importeisr:Se requiere el Monto de la Retenci&oacute;n.___';
				END IF;
			END IF;
			
			--str_data[38]	comp_subtotal
			--str_data[39]	comp_descuento
			--str_data[40]	comp_retencion
			--str_data[41]	comp_total
			--str_data[42]	percep_total_gravado
			--str_data[43]	percep_total_excento
			--str_data[44]	deduc_total_gravado
			--str_data[45]	deduc_total_excento
			--str_data[46]	percepciones
			
			--str_data[46]	percepciones
			IF str_data[46] is not null AND str_data[46]<>'' THEN 
				--Convertir en arreglo la cadena de Percepciones
				SELECT INTO str_percep string_to_array(str_data[46],'&&&');
				cont_fila=1;
				FOR cont_fila IN array_lower(str_percep,1) .. array_upper(str_percep,1) LOOP
					SELECT INTO str_filas string_to_array(str_percep[cont_fila],'|');
					--str_filas[1]	id_percep
					--str_filas[2]	noTrPercep
					--str_filas[3]	percep_monto_gravado
					--str_filas[4]	percep_monto_excento
					
					--str_data[3]	percep_monto_gravado
					IF trim(str_filas[3]) = '' THEN
						--valor_retorno := ''||valor_retorno||'grid2__percep_monto_gravado'||str_filas[2]||':Se requiere el Importe del Concepto.___';
					ELSE 
						IF str_filas[3]::double precision <=0 THEN
							--valor_retorno := ''||valor_retorno||'grid2__percep_monto_gravado'||str_filas[2]||':El Importe debe ser mayor a cero.___';
						END IF;
					END IF;
					
				END LOOP;
			END IF;
			--str_data[47]	deducciones
			--str_data[48]	hrs_extras
			--str_data[49]	incapacidades
			
		END IF;
        END IF;
        --Termina validacion Periodicidad de Pago




	--validacion de Catalogo de Configuración Periodicidad de Pago
        IF id_app=174 THEN
                --str_data[4]  id
                --str_data[5]  año 
                --str_data[6]  periodicidad de pago
		--str_data[7]  titulo

	      --año
		IF str_data[5]::integer =0 THEN
			valor_retorno := ''||valor_retorno||'select_anio:Es necesario seleccionar un A&ntilde;o.___';
		END IF;

		  --periodicidad de Pago
		IF str_data[6]::integer =0 THEN
			valor_retorno := ''||valor_retorno||'periodo:Es necesario seleccionar un tipo de Periodicidad de Pago.___';
		END IF;

		
		IF str_data[4] = '0' THEN
			--anio
			IF str_data[5] != ' ' THEN
				EXECUTE 'SELECT count(id) FROM nom_periodos_conf WHERE ano = '''||str_data[5]||''' AND nom_periodicidad_pago_id = '''||str_data[6]||''' AND borrado_logico=FALSE AND gral_suc_id='||str_data[8]||' AND gral_emp_id='||emp_id||';' INTO valida_integridad;
				IF valida_integridad > 0 THEN
					valor_retorno := ''||valor_retorno||'select_anio:El A&ntilde;o ya se encuentra registrado.___';
				END IF;
			END IF;
		ELSE
			EXECUTE 'SELECT ano, id FROM nom_periodos_conf WHERE ano='''||str_data[5]||''' AND nom_periodicidad_pago_id = '''||str_data[6]||''' AND borrado_logico=FALSE AND gral_suc_id='||str_data[8]||' AND gral_emp_id='||emp_id||';' INTO titulo_mask, valida_integridad;
			IF str_data[4]::integer != valida_integridad THEN
				valor_retorno := ''||valor_retorno||'select_anio:El A&ntilde;o ya se encuentra registrado.___';
			END IF;
		END IF;

		IF str_data[4] = '0' THEN
			--periodicidad de pago
			IF str_data[6] != ' ' THEN
				EXECUTE 'SELECT count(id) FROM nom_periodos_conf WHERE ano = '''||str_data[5]||''' AND nom_periodicidad_pago_id = '''||str_data[6]||''' AND borrado_logico=FALSE AND gral_suc_id='||str_data[8]||' AND gral_emp_id='||emp_id||';' INTO valida_integridad;
				IF valida_integridad > 0 THEN
					valor_retorno := ''||valor_retorno||'periodo:La Periodicidad de Pago ya se encuentra registrada.___';
				END IF;
			END IF;
		ELSE
			EXECUTE 'SELECT nom_periodicidad_pago_id, id FROM nom_periodos_conf WHERE ano = '''||str_data[5]||''' AND nom_periodicidad_pago_id='''||str_data[6]||''' AND borrado_logico=FALSE AND gral_suc_id='||str_data[8]||' AND gral_emp_id='||emp_id||';' INTO titulo_mask, valida_integridad;
			IF str_data[4]::integer != valida_integridad THEN
				valor_retorno := ''||valor_retorno||'periodo:La Periodicidad de Pago ya se encuentra registrada.___';
			END IF;
		END IF;

		
		IF str_data[4] = '0' THEN
			--prefijo
			IF str_data[7] != ' ' THEN
				EXECUTE 'SELECT count(id) FROM nom_periodos_conf WHERE ano = '''||str_data[5]||''' AND nom_periodicidad_pago_id='''||str_data[6]||''' AND prefijo = '''||str_data[7]||''' AND borrado_logico=FALSE AND gral_suc_id='||str_data[8]||' AND gral_emp_id='||emp_id||';' INTO valida_integridad;
				IF valida_integridad > 0 THEN
					valor_retorno := ''||valor_retorno||'titulo:EL Prefijo ya se encuentra registrado1.___';
				END IF;
			END IF;
		ELSE
			EXECUTE 'SELECT prefijo, id FROM nom_periodos_conf WHERE ano = '''||str_data[5]||''' AND nom_periodicidad_pago_id='''||str_data[6]||''' AND prefijo='''||str_data[7]||''' AND borrado_logico=FALSE AND gral_suc_id='||str_data[8]||' AND gral_emp_id='||emp_id||';' INTO titulo_mask, valida_integridad;
			IF str_data[4]::integer != valida_integridad THEN
				valor_retorno := ''||valor_retorno||'titulo:EL Prefijo ya se encuentra registrado2.___';
			END IF;
		END IF;

		-- validaciones para el grid --
		IF arreglo[1] <> 'sin datos' THEN
			total_filas:= array_length(arreglo,1);--obtiene total de elementos del arreglo
			cont_fila:=1;
			FOR cont_fila IN 1 .. total_filas LOOP
				
				SELECT INTO str_filas string_to_array(arreglo[cont_fila],'___');
				--str_filas[1]	id_reg 
				--str_filas[2]	id_periodo 
				--str_filas[3]	folio 
				--str_filas[4]	tituloperiodo
				--str_filas[5]	fecha_inicio 
				--str_filas[6]	fecha_final
				--str_filas[7]	noTr

				---VALIDACION PARA  EL GRID
				IF str_filas[5] = ' ' OR str_filas[5] = '' THEN
					valor_retorno := ''||valor_retorno||'fechainicial'||str_filas[7]||':Es necesario ingresar la fecha inicial.___';
				END IF;

				IF str_filas[6] = ' ' OR str_filas[6] = '' THEN
					valor_retorno := ''||valor_retorno||'fechafinal'||str_filas[7]||':Es necesario ingresar la fecha final.___';
				END IF;
				
				IF trim(str_filas[4])='' THEN 
					valor_retorno := ''||valor_retorno||'tituloperiodo'||str_filas[7]||':Es necesario ingresar un titulo.___';

				END IF;

				--str_filas[4]	tituloperiodo
				--str_filas[7]	noTr
				
				cont_fila2:=1;
				FOR cont_fila2 IN 1 .. array_length(arreglo,1) LOOP
					SELECT INTO str_filas2 string_to_array(arreglo[cont_fila2],'___');

					--str_filas2[4]	tituloperiodo
					--str_filas2[7]	noTr
					--Aqui se verifica en el listado si existe un elemento con la misma descripcion
					IF str_filas[4]=str_filas2[4] THEN
						--Si existe entra aquí
						--Hay que verificar que no sea el mismo elemento
						IF str_filas[7]<>str_filas2[7] THEN
							valor_retorno := ''||valor_retorno||'tituloperiodo'||str_filas[7]||':Es necesario ingresar un titulo diferente'||str_filas2[4]||'.___';

						END IF;
					END IF;

				END LOOP;

				IF str_filas[1] = '0' THEN
				--tituloperiodo
					IF str_filas[4] != ' ' THEN
						EXECUTE 'SELECT count(id) FROM nom_periodos_conf_det WHERE titulo = '''||str_filas[4]||''' AND nom_periodos_conf_id = '''||str_filas[2]||''' ;' INTO valida_integridad;
						IF valida_integridad > 0 THEN
							valor_retorno := ''||valor_retorno||'tituloperiodo'||str_filas[7]||':El Titulo ya se encuentra en uso.___';
						END IF;
					END IF;
				ELSE
					EXECUTE 'SELECT titulo, id FROM nom_periodos_conf_det WHERE  titulo='''||str_filas[4]||''' AND nom_periodos_conf_id = '''||str_filas[2]||''' ;' INTO titulo_mask, valida_integridad;
					IF str_filas[1]::integer != valida_integridad THEN
						valor_retorno := ''||valor_retorno||'tituloperiodo'||str_filas[7]||':El Titulo ya se encuentra registrado.___';
					END IF;
				END IF;
				
			END LOOP;
		
		END IF;
		
        END IF;
        --validacion de Catalogo de Configuración Periodicidad de Pago

        
	
	IF valor_retorno = '' THEN
		valor_retorno := 'true';
		RETURN valor_retorno;
	ELSE
		RETURN valor_retorno;
	END IF;
	
END;

$_$;


ALTER FUNCTION public.erp_fn_validaciones_por_aplicativo(campos_data text, id_app integer, arreglo text[]) OWNER TO sumar;

--
-- Name: fac_adm_procesos(text, text[]); Type: FUNCTION; Schema: public; Owner: sumar
--

CREATE FUNCTION fac_adm_procesos(campos_data text, extra_data text[]) RETURNS character varying
    LANGUAGE plpgsql
    AS $$


DECLARE
	str_data text[];
	str_filas text[];
	--Total de elementos de arreglo
	total_filas integer;
	--Contador de filas o posiciones del arreglo
	cont_fila integer;
	--Estas  se utilizan para la nomina
	str_percep text[];
	str_deduc text[];
	str_hrs_extras text[];
	str_incapa text[];
	refId character varying:='';
	
	valor_retorno character varying = '';
	ultimo_id integer:=0;
	ultimo_id_det integer:=0;
	id_tipo_consecutivo integer=0;
	prefijo_consecutivo character varying = '';
	nuevo_consecutivo bigint=0;
	nuevo_folio character varying = '';
	ultimo_id_proceso integer =0;

	tipo_de_documento integer =0;
	fila_fac_rem_doc record;
	
	app_selected integer;
	command_selected text;
	usuario_ejecutor integer:=0;
	emp_id integer:=0;
	suc_id integer:=0;
	suc_id_consecutivo integer:=0; --sucursal de donde se tomara el consecutivo
	id_almacen integer;
	espacio_tiempo_ejecucion timestamp with time zone = now();
	ano_actual integer:=0;
	mes_actual integer:=0;
	factura_fila record;
	prefactura_fila record;
	prefactura_detalle record;
	factura_detalle record;
	formulacion record;
	tiene_pagos integer:=0;
	identificador_nuevo_movimiento integer;
	tipo_movimiento_id integer:=0;
	exis integer:=0;
	sql_insert text;
	sql_update text;
	sql_select text;
	sql_select2 character varying:='';
	cantidad_porcentaje double precision:=0;
	id_proceso integer;
	bandera_tipo_4 boolean;--bandera que identifica si el producto es tipo 4, true=tipo 4, false=No es tipo4
	serie_folio_fac character varying:='';
	refact character varying :='';
	tipo_cam double precision := 0;
	
	numero_dias_credito integer:=0;
	fecha_de_vencimiento timestamp with time zone;
	
	importe_del_descto_partida double precision := 0;
	importe_partida_con_descto double precision := 0;
	suma_descuento double precision := 0;
	suma_subtotal_con_descuento double precision := 0;
	
	importe_partida double precision := 0;
	importe_ieps_partida double precision := 0;
	impuesto_partida double precision := 0;
	monto_subtotal double precision := 0;
	suma_ieps double precision := 0;
	suma_total double precision := 0;
	monto_impuesto double precision := 0;
	total_retencion double precision := 0;
	retener_iva boolean := false;
	tasa_retencion double precision := 0;
	retencion_partida double precision := 0;
	suma_retencion_de_partidas double precision := 0;
	suma_retencion_de_partidas_globlal double precision:= 0;
	
	--Estas variables se utilizan en caso de que se facture un pedido en otra moneda
	suma_descuento_global double precision := 0;
	suma_subtotal_con_descuento_global double precision := 0;
	monto_subtotal_global double precision := 0;
	suma_ieps_global double precision := 0;
	monto_impuesto_global double precision := 0;
	total_retencion_global double precision := 0;
	suma_total_global double precision := 0;
	cant_original double precision := 0;
	
	serie_folio_nota_credito  character varying:='';
	fecha_nota_credito timestamp with time zone;
	concepto_nota_credito character varying:='';
	aplicativo_id integer := 0; --aqui se guarda el id del aplicativo que genero la nota de credito
	
	total_factura double precision;
	id_moneda_factura integer:=0;
	suma_pagos double precision:=0;
	suma_notas_credito double precision:=0;
	nuevacantidad_monto_pago double precision:=0;
	nuevo_saldo_factura double precision:=0;
	
	costo_promedio_actual double precision:=0;
	costo_referencia_actual double precision:=0;
	
	id_osal integer := 0;
	nuevo_folio_osal character varying:='';
	fila record;
	fila_detalle record;
	facpar record;--parametros de Facturacion
	
	id_df integer:=0;--id de la direccion fiscal
	result character varying:='';

	noDecUnidad integer:=0;--numero de decimales permitidos para la unidad
	exisActualPres double precision:=0;--existencia actual de la presentacion
	equivalenciaPres double precision:=0; --equivalencia de la presentacion en la unidad del producto
	cantPres double precision:=0; --Cantidad que se esta Intentando traspasar
	cantPresAsignado double precision:=0;
	cantPresReservAnterior double precision:=0;
	
	controlExisPres boolean; --Variable que indica  si se debe controlar Existencias por Presentacion
	partida_facturada boolean;--Variable que indica si la cantidad de la partida ya fue facturada en su totalidad
	actualizar_proceso boolean; --Indica si hay que actualizar el flujo del proceso. El proceso se debe actualizar cuando ya no quede partidas vivas
	id_pedido integer;--Id del Pedido que se esta facturando
	--Id de la unidad de medida del producto
	idUnidadMedida integer:=0;
	--Nombre de la unidad de medida del producto
	nombreUnidadMedida character varying:=0;
	--Densidad del producto
	densidadProd double precision:=0;
	--Cantidad en la unidad del producto
	cantUnidadProd double precision:=0;
	--Id de la unidad de Medida de la Venta
	idUnidadMedidaVenta integer:=0;
	--Cantidad en la unidad de Venta, esto se utiliza cuando la unidad del producto es diferente a la de venta
	cantUnidadVenta double precision:=0;
	--Cantidad de la existencia convertida a la unidad de venta, esto se utiliza cuando la unidad del producto es diferente a la de venta
	cantExisUnidadVenta double precision:=0;
	match_cadena boolean:=false;
	
	--Numero de Adenda
	idAdenda integer:=0;
	moneda_iso_4217 character varying:='';
	valor_campo1 character varying:='';
	id2 integer:=0;
BEGIN
	-- convertir cadena en arreglo
	SELECT INTO str_data string_to_array(''||campos_data||'','___');
	
	-- aplicativo que manda a llamar este procedimiento almacenado
	app_selected := str_data[1]::integer;
	
	-- comando que desea ejecutar el aplicativo que llamo el procedimiento almacenado
	command_selected := str_data[2];
	
	-- usuario que utiliza el aplicativo
	usuario_ejecutor := str_data[3]::integer;
	
	SELECT EXTRACT(YEAR FROM espacio_tiempo_ejecucion) INTO ano_actual;
	SELECT EXTRACT(MONTH FROM espacio_tiempo_ejecucion) INTO mes_actual;
	
	--obtener id de empresa, sucursal
  	SELECT gral_suc.empresa_id, gral_usr_suc.gral_suc_id
  	FROM gral_usr_suc 
	JOIN gral_suc ON gral_suc.id = gral_usr_suc.gral_suc_id
	WHERE gral_usr_suc.gral_usr_id = usuario_ejecutor
	INTO emp_id, suc_id;
	
	--Obtener parametros para la facturacion
	SELECT * FROM fac_par WHERE gral_suc_id=suc_id INTO facpar;
	
	--tomar el id del almacen para ventas
	id_almacen := facpar.inv_alm_id;
	
	--éste consecutivo es para el folio de Remisión y folio para BackOrder(poc_ped_bo)
	suc_id_consecutivo := facpar.gral_suc_id_consecutivo;

	--query para verificar si la Empresa actual incluye Modulo de Produccion y control de Existencias por Presentacion
	SELECT control_exis_pres FROM gral_emp WHERE id=emp_id INTO controlExisPres;
	
	--Inicializar en cero
	id_pedido:=0;
	
	-- Factura de NOMINA
	IF app_selected = 173 THEN
		--Aqui entra para crear el nuevo registro del Header de la Nomina
		IF command_selected = 'new' THEN 
			--str_data[1]	app_selected
			--str_data[2]	command_selected
			--str_data[3]	id_usuario
			--str_data[4]	identificador
			--str_data[5]	comp_tipo
			--str_data[6]	comp_forma_pago
			--str_data[7]	comp_tc
			--str_data[8]	comp_no_cuenta
			--str_data[9]	fecha_pago
			--str_data[10]	select_comp_metodo_pago
			--str_data[11]	select_comp_moneda
			--str_data[12]	select_comp_periodicidad
			--str_data[13]	select_no_periodo
			
			IF trim(str_data[7])='' THEN str_data[7]:='0'; END IF;
			
			INSERT INTO fac_nomina(
				id, --str_data[4]::integer,
				tipo_comprobante, --str_data[5],
				forma_pago, --str_data[6],
				tipo_cambio, --str_data[7]::double precision,
				no_cuenta, --str_data[8],
				fecha_pago, --str_data[9]::date,
				fac_metodos_pago_id, --str_data[10]::integer,
				gral_mon_id, --str_data[11]::integer,
				nom_periodicidad_pago_id, --str_data[12]::integer,
				nom_periodos_conf_det_id, --str_data[13]::integer,
				momento_creacion,--espacio_tiempo_ejecucion,
				gral_usr_id_creacion,--usuario_ejecutor,
				gral_emp_id, --emp_id,
				gral_suc_id --suc_id
			)VALUES(str_data[4]::integer, str_data[5], str_data[6], str_data[7]::double precision, str_data[8], str_data[9]::date, str_data[10]::integer, str_data[11]::integer, str_data[12]::integer, str_data[13]::integer, espacio_tiempo_ejecucion, usuario_ejecutor, emp_id, suc_id)
			RETURNING id INTO ultimo_id;
			
			total_filas:= array_length(extra_data,1);
			cont_fila:=1;
			
			IF extra_data[1]<>'sin datos' THEN
				FOR cont_fila IN 1 .. total_filas LOOP
					SELECT INTO str_filas string_to_array(extra_data[cont_fila],'___');
					--str_filas[1]	elim 
					--str_filas[2]	noTr 
					--str_filas[3]	id_reg 
					--str_filas[4]	id_empleado
					--str_filas[5]	total_percep
					--str_filas[6]	total_deduc
					--str_filas[7]	pago_neto
					
					IF str_filas[1]::integer<>0 THEN --1: no esta esta Eliminado, 0:Si esta Eliminado
						--Crear registro en fac_nomina_det
						INSERT INTO fac_nomina_det(fac_nomina_id, gral_empleado_id )
						VALUES(ultimo_id,str_filas[4]::integer);
					END IF;
				END LOOP;
			END IF;
			
			--valor_actualizado||id_registro||codigo_error||mensaje
			valor_retorno := '1:'||ultimo_id||':'||'0'||':Los datos se guardaron con exito.';
		END IF;
		--Termina new Nomina
		
		
		IF command_selected = 'edit' THEN 
			--str_data[1]	app_selected
			--str_data[2]	command_selected
			--str_data[3]	id_usuario
			--str_data[4]	identificador
			--str_data[5]	comp_tipo
			--str_data[6]	comp_forma_pago
			--str_data[7]	comp_tc
			--str_data[8]	comp_no_cuenta
			--str_data[9]	fecha_pago
			--str_data[10]	select_comp_metodo_pago
			--str_data[11]	select_comp_moneda
			--str_data[12]	select_comp_periodicidad
			--str_data[13]	select_no_periodo
			
			IF trim(str_data[7])='' THEN str_data[7]:='0'; END IF;
			
			UPDATE fac_nomina SET tipo_comprobante=str_data[5], forma_pago=str_data[6], tipo_cambio=str_data[7]::double precision, no_cuenta=str_data[8], fecha_pago=str_data[9]::date, fac_metodos_pago_id=str_data[10]::integer, gral_mon_id=str_data[11]::integer, nom_periodicidad_pago_id=str_data[12]::integer, nom_periodos_conf_det_id=str_data[13]::integer, momento_actualizacion=espacio_tiempo_ejecucion, gral_usr_id_actualizacion=usuario_ejecutor 
			WHERE id=str_data[4]::integer
			RETURNING id INTO ultimo_id;
			
			IF extra_data[1]<>'sin datos' THEN
				total_filas:= array_length(extra_data,1);
				cont_fila:=1;
				FOR cont_fila IN 1 .. total_filas LOOP
					SELECT INTO str_filas string_to_array(extra_data[cont_fila],'___');
					--str_filas[1]	elim 
					--str_filas[2]	noTr 
					--str_filas[3]	id_reg 
					--str_filas[4]	id_empleado
					--str_filas[5]	total_percep
					--str_filas[6]	total_deduc
					--str_filas[7]	pago_neto

					IF str_filas[3]::integer > 0 THEN 
						IF str_filas[1]::integer=0 THEN --1: no esta esta Eliminado, 0:Si esta Eliminado
							DELETE FROM fac_nomina_det WHERE id=str_filas[3]::integer;
							DELETE FROM fac_nomina_det_deduc WHERE fac_nomina_det_id=str_filas[3]::integer;
							DELETE FROM fac_nomina_det_percep WHERE fac_nomina_det_id=str_filas[3]::integer;
							DELETE FROM fac_nomina_det_hrs_extra WHERE fac_nomina_det_id=str_filas[3]::integer;
							DELETE FROM fac_nomina_det_incapa WHERE fac_nomina_det_id=str_filas[3]::integer;
						END IF;
					ELSE
						IF str_filas[3]::integer=0 THEN 
							--Aqui se verifica si el id del registro viene en cero
							SELECT id::character varying FROM fac_nomina_det WHERE fac_nomina_id=str_data[4]::integer AND gral_empleado_id=str_filas[4]::integer 
							INTO str_filas[3];
							
							IF str_filas[3] IS NULL THEN str_filas[3]:='0'; END IF;
						END IF;
						IF str_filas[3]::integer<=0 THEN 
							--Crear registro en fac_nomina_det
							INSERT INTO fac_nomina_det(fac_nomina_id, gral_empleado_id )VALUES(str_data[4]::integer,str_filas[4]::integer);
						END IF;
					END IF;
				END LOOP;
			END IF;
			
			--valor_actualizado||id_registro||codigo_error||mensaje
			valor_retorno := '1:'||ultimo_id||':'||'0'||':Los datos se guardaron con exito.';
		END IF;
		--Termina EDIT Nomina





		--FACTURAR Nomina por Empleado(Actualizar registros para indicar que ya fue facturado)
		IF command_selected = 'facturar_nomina' THEN 
			--str_data[1]	app_selected
			--str_data[2]	command_selected
			--str_data[3]	id_usuario
			--str_data[4]	nom_det_id
			--str_data[5]	empleado_id
			--str_data[6]	ref_id
			--str_data[7]	Serie
			--str_data[8]	Folio
			--str_data[9]	cadena_xml

			--Actualiza el registro para indicar que se ha generado CFDi de Nomina
			UPDATE fac_nomina_det SET facturado=true, serie=str_data[7],folio=str_data[8],ref_id=str_data[6], momento_facturacion=espacio_tiempo_ejecucion, gral_usr_id_facturacion=usuario_ejecutor 
			WHERE id=str_data[4]::integer AND gral_empleado_id=str_data[5]::integer RETURNING fac_nomina_id INTO ultimo_id;
			
			--Guarda la cadena del xml timbrado
			INSERT INTO fac_cfdis(tipo, ref_id, doc, gral_emp_id, gral_suc_id, fecha_crea, gral_usr_id_crea) VALUES (3,str_data[6],str_data[9]::text,emp_id,suc_id,espacio_tiempo_ejecucion, usuario_ejecutor);
			
			--Obtener el ID del numero de periodo
			SELECT nom_periodos_conf_det_id FROM fac_nomina WHERE id=ultimo_id LIMIT 1 INTO id2;
			IF id2 IS NULL THEN id2:=0; END IF;
			
			IF (SELECT count(id) FROM fac_nomina_det WHERE fac_nomina_id=ultimo_id AND facturado=false)<=0 THEN 
				--Actualiza para indicar se ha generado CFDI de todos los registros de NOMINA
				UPDATE fac_nomina SET status=2 WHERE id=ultimo_id;
			ELSE
				--Actualiza para indicar se ha generado CFDI de por lo menos un registro de NOMINA
				UPDATE fac_nomina SET status=1 WHERE id=ultimo_id;
			END IF;
			
			--Actualizar el periodo actual para indicar que ya fue generado la nomina correspondiente
			UPDATE nom_periodos_conf_det SET estatus=true WHERE id=id2;
			
			--Actualiza el consecutivo del folio de Nominas en la tabla fac_cfds_conf_folios. La actualización es por Empresa-sucursal
			UPDATE fac_cfds_conf_folios SET folio_actual=(folio_actual+1) WHERE id=(SELECT fac_cfds_conf_folios.id FROM fac_cfds_conf JOIN fac_cfds_conf_folios ON fac_cfds_conf_folios.fac_cfds_conf_id=fac_cfds_conf.id WHERE lower(trim(fac_cfds_conf_folios.proposito))='nom' AND fac_cfds_conf.empresa_id=emp_id AND fac_cfds_conf.gral_suc_id=suc_id);
			
			--valor_actualizado||id_registro||codigo_error||mensaje
			valor_retorno := '1:'||ultimo_id||':'||'0'||':Se ha creado el CFDI de Nomina'||str_data[7]||str_data[8]||'.';
		END IF;
		--Termina FACTURAR Nomina



		--CANCELAR CFDI DE NOMINA
		IF command_selected = 'cancelacion_cfdi_nomina' THEN 
			--str_data[1]	app_selected
			--str_data[2]	command_selected
			--str_data[3]	id_usuario
			--str_data[4]	id_reg
			--str_data[5]	id_empleado
			
			--Actualiza el registro para indicar que se ha generado CFDi de Nomina
			UPDATE fac_nomina_det SET cancelado=true, momento_cancelacion=espacio_tiempo_ejecucion, gral_usr_id_cancela=usuario_ejecutor 
			WHERE id=str_data[4]::integer AND gral_empleado_id=str_data[5]::integer RETURNING ref_id INTO refId;
			
			--Actualiza el registro de xmls
			UPDATE fac_cfdis SET cancelado=true, fecha_cancela=espacio_tiempo_ejecucion, gral_usr_id_cancela=usuario_ejecutor 
			WHERE tipo=3 AND ref_id=refId AND gral_emp_id=emp_id;
			
			--valor_actualizado||id_registro||codigo_error||mensaje
			valor_retorno := '1:Se ha CANCELADO el CFDI de Nomina '||refId;
		END IF;
		--Termina FACTURAR Nomina



		
		
		--Guarda datos de la nomina de un empleado en especifico
		IF command_selected = 'new_nomina' THEN 
			--str_data[1]	app_selected
			--str_data[2]	command_selected
			--str_data[3]	id_usuario
			--str_data[4]	identificador
			--str_data[5]	id_reg
			--str_data[6]	id_empleado
			--str_data[7]	no_empleado
			--str_data[8]	rfc_empleado
			--str_data[9]	nombre_empleado
			--str_data[10]	select_departamento
			--str_data[11]	select_puesto
			--str_data[12]	fecha_contrato
			--str_data[13]	antiguedad
			--str_data[14]	curp
			--str_data[15]	select_reg_contratacion
			--str_data[16]	select_tipo_contrato
			--str_data[17]	select_tipo_jornada
			--str_data[18]	select_preriodo_pago
			--str_data[19]	clabe
			--str_data[20]	select_banco
			--str_data[21]	select_riesgo_puesto
			--str_data[22]	imss
			--str_data[23]	reg_patronal
			--str_data[24]	salario_base
			--str_data[25]	fecha_ini_pago
			--str_data[26]	fecha_fin_pago
			--str_data[27]	salario_integrado
			--str_data[28]	no_dias_pago
			--str_data[29]	concepto_descripcion
			--str_data[30]	concepto_unidad
			--str_data[31]	concepto_cantidad
			--str_data[32]	concepto_valor_unitario
			--str_data[33]	concepto_importe
			--str_data[34]	descuento
			--str_data[35]	motivo_descuento
			--str_data[36]	select_impuesto_retencion
			--str_data[37]	importe_retencion
			--str_data[38]	comp_subtotal
			--str_data[39]	comp_descuento
			--str_data[40]	comp_retencion
			--str_data[41]	comp_total
			--str_data[42]	percep_total_gravado
			--str_data[43]	percep_total_excento
			--str_data[44]	deduc_total_gravado
			--str_data[45]	deduc_total_excento
			--str_data[46]	percepciones
			--str_data[47]	deducciones
			--str_data[48]	hrs_extras
			--str_data[49]	incapacidades
			
			IF str_data[5]::integer=0 THEN 
				--Aqui se verifica si el id del registro viene en cero
				SELECT id::character varying FROM fac_nomina_det WHERE fac_nomina_id=str_data[4]::integer AND gral_empleado_id=str_data[6]::integer 
				INTO str_data[5];
				
				IF str_data[5] IS NULL THEN str_data[5]:='0'; END IF;
			END IF;
			
			IF str_data[5]::integer>0 THEN
				--Se actualiza porque el registro ya existe
				UPDATE fac_nomina_det SET gral_empleado_id = str_data[6]::integer, no_empleado = str_data[7], rfc = str_data[8], nombre = str_data[9], curp = str_data[14], gral_depto_id = str_data[10]::integer, gral_puesto_id = str_data[11]::integer, fecha_contrato = str_data[12]::date, antiguedad = str_data[13]::integer, nom_regimen_contratacion_id = str_data[15]::integer, nom_tipo_contrato_id = str_data[16]::integer, nom_tipo_jornada_id = str_data[17]::integer, nom_periodicidad_pago_id = str_data[18]::integer, clabe = str_data[19], tes_ban_id = str_data[20]::integer, nom_riesgo_puesto_id = str_data[21]::integer, imss = str_data[22], reg_patronal = str_data[23], salario_base = str_data[24]::double precision, salario_integrado = str_data[27]::double precision, fecha_ini_pago = str_data[25]::date, fecha_fin_pago = str_data[26]::date, no_dias_pago = str_data[28]::integer, concepto_descripcion = str_data[29], concepto_unidad = str_data[30], concepto_cantidad = str_data[31]::double precision, concepto_valor_unitario = str_data[32]::double precision, concepto_importe = str_data[33]::double precision, descuento = str_data[34]::double precision, motivo_descuento = str_data[35], gral_isr_id = str_data[36]::integer, importe_retencion = str_data[37]::double precision, comp_subtotal = str_data[38]::double precision, comp_descuento = str_data[39]::double precision, comp_retencion = str_data[40]::double precision, comp_total = str_data[41]::double precision, percep_total_gravado = str_data[42]::double precision, percep_total_excento = str_data[43]::double precision, deduc_total_gravado = str_data[44]::double precision, deduc_total_excento = str_data[45]::double precision, validado=true 
				WHERE id=str_data[5]::integer 
				RETURNING id INTO ultimo_id;
				
				--Se eliminan estos registros porque mas adelante se vuelven a crear
				DELETE FROM fac_nomina_det_percep WHERE fac_nomina_det_id = ultimo_id;
				DELETE FROM fac_nomina_det_deduc WHERE fac_nomina_det_id = ultimo_id;
				DELETE FROM fac_nomina_det_hrs_extra WHERE fac_nomina_det_id = ultimo_id;
				DELETE FROM fac_nomina_det_incapa WHERE fac_nomina_det_id = ultimo_id;
			ELSE
				--Se crea nuevo registro
				INSERT INTO fac_nomina_det(fac_nomina_id, gral_empleado_id, no_empleado, rfc, nombre, curp, gral_depto_id, gral_puesto_id, fecha_contrato, antiguedad, nom_regimen_contratacion_id, nom_tipo_contrato_id, nom_tipo_jornada_id, nom_periodicidad_pago_id, clabe, tes_ban_id, nom_riesgo_puesto_id, imss, reg_patronal, salario_base, salario_integrado, fecha_ini_pago, fecha_fin_pago, no_dias_pago, concepto_descripcion, concepto_unidad, concepto_cantidad, concepto_valor_unitario, concepto_importe, descuento, motivo_descuento, gral_isr_id, importe_retencion, comp_subtotal, comp_descuento, comp_retencion, comp_total, percep_total_gravado, percep_total_excento, deduc_total_gravado, deduc_total_excento, validado)
				values(str_data[4]::integer, str_data[6]::integer, str_data[7], str_data[8], str_data[9], str_data[14], str_data[10]::integer, str_data[11]::integer, str_data[12]::date, str_data[13]::integer, str_data[15]::integer, str_data[16]::integer, str_data[17]::integer, str_data[18]::integer, str_data[19], str_data[20]::integer, str_data[21]::integer, str_data[22], str_data[23], str_data[24]::double precision, str_data[27]::double precision, str_data[25]::date, str_data[26]::date, str_data[28]::integer, str_data[29], str_data[30], str_data[31]::double precision, str_data[32]::double precision, str_data[33]::double precision, str_data[34]::double precision, str_data[35], str_data[36]::integer, str_data[37]::double precision, str_data[38]::double precision, str_data[39]::double precision, str_data[40]::double precision, str_data[41]::double precision, str_data[42]::double precision, str_data[43]::double precision, str_data[44]::double precision, str_data[45]::double precision, true)
				RETURNING id INTO ultimo_id;
			END IF;
			
			--str_data[46]	percepciones
			IF str_data[46] is not null AND str_data[46]<>'' THEN
				--Convertir en arreglo la cadena de Percepciones
				SELECT INTO str_percep string_to_array(str_data[46],'&&&');
				cont_fila=1;
				FOR cont_fila IN array_lower(str_percep,1) .. array_upper(str_percep,1) LOOP
					SELECT INTO str_filas string_to_array(str_percep[cont_fila],'|');
					--str_filas[1]	id_percep
					--str_filas[2]	noTrPercep
					--str_filas[3]	percep_monto_gravado
					--str_filas[4]	percep_monto_excento
					INSERT INTO fac_nomina_det_percep(fac_nomina_det_id,nom_percep_id,gravado,excento) 
					VALUES (ultimo_id,str_filas[1]::integer,str_filas[3]::double precision,str_filas[4]::double precision);
				END LOOP;
			END IF;
			
			--str_data[47]	deducciones
			IF str_data[47] is not null AND str_data[47]<>'' THEN
				--Convertir en arreglo la cadena de Deducciones
				SELECT INTO str_deduc string_to_array(str_data[47],'&&&');
				cont_fila=1;
				FOR cont_fila IN array_lower(str_deduc,1) .. array_upper(str_deduc,1) LOOP
					SELECT INTO str_filas string_to_array(str_deduc[cont_fila],'|');
					--str_filas[1]	id_deduc
					--str_filas[2]	noTrDeduc
					--str_filas[3]	deduc_monto_gravado
					--str_filas[4]	deduc_monto_excento
					INSERT INTO fac_nomina_det_deduc(fac_nomina_det_id,nom_deduc_id,gravado,excento) 
					VALUES (ultimo_id,str_filas[1]::integer,str_filas[3]::double precision,str_filas[4]::double precision);
				END LOOP;
			END IF;
			
			--str_data[48]	hrs_extras
			IF str_data[48] is not null AND str_data[48]<>'' THEN
				--Convertir en arreglo la cadena de Horas Extras
				SELECT INTO str_hrs_extras string_to_array(str_data[48],'&&&');
				cont_fila=1;
				FOR cont_fila IN array_lower(str_hrs_extras,1) .. array_upper(str_hrs_extras,1) LOOP
					SELECT INTO str_filas string_to_array(str_hrs_extras[cont_fila],'|');
					--str_filas[1]	id_he
					--str_filas[2]	noTrhe
					--str_filas[3]	select_tipo_he
					--str_filas[4]	he_no_dias
					--str_filas[5]	he_no_horas
					--str_filas[6]	he_importe
					INSERT INTO fac_nomina_det_hrs_extra(fac_nomina_det_id, nom_tipo_hrs_extra_id ,no_dias, no_hrs, importe) 
					VALUES (ultimo_id,str_filas[3]::integer,str_filas[4]::double precision,str_filas[5]::double precision, str_filas[6]::double precision);
				END LOOP;
			END IF;

			
			--str_data[49]	incapacidades
			IF str_data[49] is not null AND str_data[49]<>'' THEN
				--Convertir en arreglo la cadena de Horas Extras
				SELECT INTO str_incapa string_to_array(str_data[49],'&&&');
				cont_fila=1;
				FOR cont_fila IN array_lower(str_incapa,1) .. array_upper(str_incapa,1) LOOP
					SELECT INTO str_filas string_to_array(str_incapa[cont_fila],'|');
					--str_filas[1]	id_incapacidad
					--str_filas[2]	noTrIncapacidad
					--str_filas[3]	select_tipo_incapacidad
					--str_filas[4]	incapacidad_no_dias
					--str_filas[5]	incapacidad_importe
					INSERT INTO fac_nomina_det_incapa(fac_nomina_det_id, nom_tipo_incapacidad_id, no_dias, importe) 
					VALUES (ultimo_id, str_filas[3]::integer, str_filas[4]::double precision, str_filas[5]::double precision);
				END LOOP;
			END IF;
			
			IF ultimo_id IS NULL THEN ultimo_id=0; END IF;
			
			--valor_actualizado||id_registro||codigo_error||mensaje
			valor_retorno := '1:'||ultimo_id||':'||'0'||':Los datos se guardaron con exito.';
		END IF;
		--Termina NEW Nomina Empleado
		
		
		
		--Editar el registro de Nomina de un empleado
		IF command_selected = 'edit_nomina' THEN 
			IF str_data[5]::integer=0 THEN 
				--Aqui se verifica si el id del registro viene en cero
				SELECT id::character varying FROM fac_nomina_det WHERE fac_nomina_id=str_data[4]::integer AND gral_empleado_id=str_data[6]::integer 
				INTO str_data[5];
				
				IF str_data[5] IS NULL THEN str_data[5]:='0'; END IF;
			END IF;
			
			IF trim(str_data[13])='' THEN str_data[13]:='0'; END IF;
			
			UPDATE fac_nomina_det SET gral_empleado_id = str_data[6]::integer, no_empleado = str_data[7], rfc = str_data[8], nombre = str_data[9], curp = str_data[14], gral_depto_id = str_data[10]::integer, gral_puesto_id = str_data[11]::integer, fecha_contrato = str_data[12]::date, antiguedad = str_data[13]::integer, nom_regimen_contratacion_id = str_data[15]::integer, nom_tipo_contrato_id = str_data[16]::integer, nom_tipo_jornada_id = str_data[17]::integer, nom_periodicidad_pago_id = str_data[18]::integer, clabe = str_data[19], tes_ban_id = str_data[20]::integer, nom_riesgo_puesto_id = str_data[21]::integer, imss = str_data[22], reg_patronal = str_data[23], salario_base = str_data[24]::double precision, salario_integrado = str_data[27]::double precision, fecha_ini_pago = str_data[25]::date, fecha_fin_pago = str_data[26]::date, no_dias_pago = str_data[28]::integer, concepto_descripcion = str_data[29], concepto_unidad = str_data[30], concepto_cantidad = str_data[31]::double precision, concepto_valor_unitario = str_data[32]::double precision, concepto_importe = str_data[33]::double precision, descuento = str_data[34]::double precision, motivo_descuento = str_data[35], gral_isr_id = str_data[36]::integer, importe_retencion = str_data[37]::double precision, comp_subtotal = str_data[38]::double precision, comp_descuento = str_data[39]::double precision, comp_retencion = str_data[40]::double precision, comp_total = str_data[41]::double precision, percep_total_gravado = str_data[42]::double precision, percep_total_excento = str_data[43]::double precision, deduc_total_gravado = str_data[44]::double precision, deduc_total_excento = str_data[45]::double precision, validado=true 
			WHERE id=str_data[5]::integer 
			RETURNING id INTO ultimo_id;
			
			--Eliminar los registros de percepciones de nomina
			DELETE FROM fac_nomina_det_percep WHERE fac_nomina_det_id = ultimo_id;
			
			--str_data[46]	percepciones
			IF str_data[46] is not null AND str_data[46]<>'' THEN 
				--Convertir en arreglo la cadena de Percepciones
				SELECT INTO str_percep string_to_array(str_data[46],'&&&');
				cont_fila=1;
				FOR cont_fila IN array_lower(str_percep,1) .. array_upper(str_percep,1) LOOP
					SELECT INTO str_filas string_to_array(str_percep[cont_fila],'|');
					
					--Volver a crear los registros de las percepciones de nomina
					INSERT INTO fac_nomina_det_percep(fac_nomina_det_id,nom_percep_id,gravado,excento) VALUES (ultimo_id,str_filas[1]::integer,str_filas[3]::double precision,str_filas[4]::double precision);
				END LOOP;
			END IF;


			--Eliminar los registros de Deducciones de nomina
			DELETE FROM fac_nomina_det_deduc WHERE fac_nomina_det_id = ultimo_id;
			
			--str_data[47]	deducciones
			IF str_data[47] is not null AND str_data[47]<>'' THEN
				--Convertir en arreglo la cadena de Deducciones
				SELECT INTO str_deduc string_to_array(str_data[47],'&&&');
				cont_fila=1;
				FOR cont_fila IN array_lower(str_deduc,1) .. array_upper(str_deduc,1) LOOP
					SELECT INTO str_filas string_to_array(str_deduc[cont_fila],'|');
					
					--Volver a crear los registros de las deducciones de nomina
					INSERT INTO fac_nomina_det_deduc(fac_nomina_det_id,nom_deduc_id,gravado,excento) VALUES (ultimo_id,str_filas[1]::integer,str_filas[3]::double precision,str_filas[4]::double precision);
				END LOOP;
			END IF;


			--Eliminar los registros de Horas Extras de nomina
			DELETE FROM fac_nomina_det_hrs_extra WHERE fac_nomina_det_id = ultimo_id;
			
			--str_data[48]	hrs_extras
			IF str_data[48] is not null AND str_data[48]<>'' THEN
				--Convertir en arreglo la cadena de Horas Extras
				SELECT INTO str_hrs_extras string_to_array(str_data[48],'&&&');
				cont_fila=1;
				FOR cont_fila IN array_lower(str_hrs_extras,1) .. array_upper(str_hrs_extras,1) LOOP
					SELECT INTO str_filas string_to_array(str_hrs_extras[cont_fila],'|');
					--Volver a crear los registros de las horas extras de nomina
					INSERT INTO fac_nomina_det_hrs_extra(fac_nomina_det_id, nom_tipo_hrs_extra_id ,no_dias, no_hrs, importe) 
					VALUES (ultimo_id,str_filas[3]::integer,str_filas[4]::double precision,str_filas[5]::double precision, str_filas[6]::double precision);
				END LOOP;
			END IF;
			
			--Eliminar los registros de Incapacidades de nomina
			DELETE FROM fac_nomina_det_incapa WHERE fac_nomina_det_id = ultimo_id;
			
			--str_data[49]	incapacidades
			IF str_data[49] is not null AND str_data[49]<>'' THEN
				--Convertir en arreglo la cadena de Horas Extras
				SELECT INTO str_incapa string_to_array(str_data[49],'&&&');
				cont_fila=1;
				FOR cont_fila IN array_lower(str_incapa,1) .. array_upper(str_incapa,1) LOOP
					SELECT INTO str_filas string_to_array(str_incapa[cont_fila],'|');
					--Volver a crear los registros de Incapacidades de nomina
					INSERT INTO fac_nomina_det_incapa(fac_nomina_det_id, nom_tipo_incapacidad_id, no_dias, importe) VALUES (ultimo_id, str_filas[3]::integer, str_filas[4]::double precision, str_filas[5]::double precision);
				END LOOP;
			END IF;
			
			IF ultimo_id IS NULL THEN ultimo_id=0; END IF;
			
			--valor_actualizado||id_registro||codigo_error||mensaje
			valor_retorno := '1:'||ultimo_id||':'||'0'||':Los datos se guardaron con exito.';
		END IF;
		--Termina EDIT Nomina Empleado
		
	END IF;
	--Termina Factura de NOMINA
	
	RETURN valor_retorno; 

END;$$;


ALTER FUNCTION public.fac_adm_procesos(campos_data text, extra_data text[]) OWNER TO sumar;

--
-- Name: gral_adm_catalogos(text, text[]); Type: FUNCTION; Schema: public; Owner: sumar
--

CREATE FUNCTION gral_adm_catalogos(campos_data text, extra_data text[]) RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    
    --estas  variables se utilizan en la mayoria de los catalogos
    str_data text[];
    str_percep text[];
    str_deduc text[];
    
    app_selected integer;
    command_selected text;
    valor_retorno character varying;
    usuario_id integer;
    emp_id integer;
    suc_id integer;
    id_almacen integer=0;
    ultimo_id integer;
    espacio_tiempo_ejecucion timestamp with time zone = now();
    ano_actual integer;
    mes_actual integer;

    exis integer=0;
    
    id_tipo_consecutivo integer=0;
    prefijo_consecutivo character varying = '';
    nuevo_consecutivo bigint=0;
    nuevo_folio character varying = '';

    incluye_modulo_produccion boolean;
    incluye_modulo_envasado boolean;
    incluye_modulo_contabilidad boolean;
    controlExisPres boolean = false;--Variable que indica si se debe controlar las existencias por presentaciones
    incluye_nomina boolean:=false;

    str_filas text[];
    total_filas integer;--total de elementos de arreglo
    cont_fila integer;--contador de filas o posiciones del arreglo
    rowCount integer;

    tipo_producto integer;
    id_producto integer;
    str_pres text[];
    tot_filas integer;--total de elementos de arreglo de id de presentaciones
    meta_imp character varying='';

    ultimo_id_usr integer=0;
    valor1 double precision:=0;

    fila record;
    fila2 record;

BEGIN
    --convertir cadena en arreglo
    SELECT INTO str_data string_to_array(''||campos_data||'','___');
    
    --aplicativo seleccionado
    app_selected := str_data[1]::integer;
    
    command_selected := str_data[2];--new, edit, delete. Para aplicativo 14 pagos: pago, anticipo, cancelacion
    
    -- usuario que utiliza el aplicativo
    usuario_id := str_data[3]::integer;

    --obtiene empresa_id, sucursal_id y sucursal_id
    SELECT gral_suc.empresa_id, gral_usr_suc.gral_suc_id,inv_suc_alm.almacen_id FROM gral_usr_suc 
    JOIN gral_suc ON gral_suc.id = gral_usr_suc.gral_suc_id
    JOIN inv_suc_alm ON inv_suc_alm.sucursal_id = gral_suc.id
    WHERE gral_usr_suc.gral_usr_id=usuario_id
    INTO emp_id, suc_id, id_almacen;

    SELECT EXTRACT(YEAR FROM espacio_tiempo_ejecucion) INTO ano_actual;
    SELECT EXTRACT(MONTH FROM espacio_tiempo_ejecucion) INTO mes_actual;
	
    valor_retorno:='0';

    --Query para verificar si la empresa actual incluye Control de Existencias por Presentacion
    SELECT control_exis_pres,nomina,incluye_contabilidad FROM gral_emp WHERE id=emp_id 
    INTO controlExisPres, incluye_nomina,incluye_modulo_contabilidad;

    --Catalogo de Empleados
    IF app_selected = 4 THEN
		IF command_selected = 'new' THEN

			id_tipo_consecutivo:=15;--Consecutivo de clave empleado
			
			--aqui entra para tomar el consecutivo del folio  la sucursal actual
			UPDATE 	gral_cons SET consecutivo=( SELECT sbt.consecutivo + 1  FROM gral_cons AS sbt WHERE sbt.id=gral_cons.id )
			WHERE gral_emp_id=emp_id AND gral_suc_id=suc_id AND gral_cons_tipo_id=id_tipo_consecutivo  RETURNING prefijo,consecutivo INTO prefijo_consecutivo,nuevo_consecutivo;
			
			--concatenamos el prefijo y el nuevo consecutivo para obtener el nuevo folio 
			nuevo_folio := prefijo_consecutivo || nuevo_consecutivo::character varying;
			
			--RAISE EXCEPTION '%','datos: '||extra_data;
			--RAISE EXCEPTION '%','nombre_consecutivo: '||nombre_consecutivo;
			--RAISE EXCEPTION '%','cadena_extra: '||cadena_extra;
			--RAISE EXCEPTION '%','numero_control_client: '||numero_control_client;

			IF trim(str_data[13])='' THEN
				str_data[13]:='2014-01-01';
			END IF;

			IF trim(str_data[61])='' THEN
				str_data[61]:='0';
			END IF;

			IF trim(str_data[62])='' THEN
				str_data[62]:='0';
			END IF;
			
			INSERT INTO gral_empleados(
				clave,--nuevo_folio,                       
				nombre_pila,--=str_data[5],
				apellido_paterno,--=str_data[6],
				apellido_materno,--=str_data[7],
				imss,--=str_data[8],
				infonavit,--=str_data[9],
				curp,--=str_data[10],
				rfc,--=str_data[11],
				fecha_nacimiento,--=str_data[12]::date,
				fecha_ingreso,--=str_data[13]::date,
				gral_escolaridad_id,--=str_data[14]::integer,
				gral_sexo_id,--=str_data[15]::integer,
				gral_civil_id,--=str_data[16]::integer,
				gral_religion_id,--=str_data[17]::integer,
				gral_sangretipo_id,--=str_data[30]::integer,
				gral_puesto_id,--=str_data[33]::integer,
				gral_categ_id,--=str_data[35]::integer,
				gral_suc_id_empleado,--=str_data[34]::integer,
				telefono,--=str_data[18],
				telefono_movil,--=str_data[19],
				correo_personal,--=str_data[20],
				gral_pais_id,--=str_data[21]::integer,
				gral_edo_id,--=str_data[22]::integer,
				gral_mun_id,--=str_data[23]::integer,
				calle,--=str_data[24],
				numero,--=str_data[25],
				colonia,--=str_data[26],
				cp,--=str_data[27],
				contacto_emergencia,--=str_data[28],
				telefono_emergencia,--=str_data[29],
				enfermedades,--=str_data[31],
				alergias,--=str_data[32],
				comentarios,--=str_data[36],
				comision_agen,--=str_data[41],
				region_id_agen,--=str_data[48],
				comision2_agen,--=str_data[42],
				comision3_agen,--=str_data[43],
				comision4_agen,--=str_data[44],
				dias_tope_comision,--=str_data[45],
				dias_tope_comision2,--=str_data[46],
				dias_tope_comision3,--=str_data[47],
				tipo_comision,--str_data[49]::integer,
				monto_tope_comision,--=str_data[50],
				monto_tope_comision2,--=str_data[51],
				monto_tope_comision3,--=str_data[52],
				correo_empresa,--str_data[53],
				no_int,--str_data[54],
				nom_regimen_contratacion_id,--str_data[55]::integer,
				nom_tipo_contrato_id,--str_data[56]::integer,
				nom_tipo_jornada_id,--str_data[57]::integer,
				nom_periodicidad_pago_id,--str_data[58]::integer,
				tes_ban_id,--str_data[59]::integer,
				nom_riesgo_puesto_id,--str_data[60]::integer,
				salario_base,--str_data[61]::double precision,
				salario_integrado,--str_data[62]::double precision,
				registro_patronal,--str_data[63],
				clabe, --str_data[64],
				genera_nomina, --str_data[67]::boolean,
				gral_depto_id, --str_data[68]::integer,
				momento_creacion,--now()
				gral_usr_id_creacion,
				gral_emp_id,
				gralsuc_id
				)VALUES (
				--Información: data_string: 4___new___1___0___[3]ADMIN___[4]SANTOS___[5]CAMPOS___[6]12345678901___[7]12345678901___[8]MASN831210MK7___[9]MASN831210MK7___[10]2012-08-09___[11]2012-08-15___3___2___2___7___1234567891_________2___19___986___AV.JUAREZ___12___MARIA LUISA___64988___EZEQUIEL CARDENAS___1234567891___2_________4
					nuevo_folio,                       
					str_data[5],
					str_data[6],
					str_data[7],
					str_data[8],
					str_data[9],
					str_data[10],
					str_data[11],
					str_data[12]::date,
					str_data[13]::date,
					str_data[14]::integer,
					str_data[15]::integer,
					str_data[16]::integer,
					str_data[17]::integer,
					str_data[30]::integer,
					str_data[33]::integer,
					str_data[35]::integer,
					str_data[34]::integer,
					str_data[18],
					str_data[19],
					str_data[20],
					str_data[21]::integer,
					str_data[22]::integer,
					str_data[23]::integer,
					str_data[24],
					str_data[25],
					str_data[26],
					str_data[27],
					str_data[28],
					str_data[29],
					str_data[31],
					str_data[32],
					str_data[36],
					str_data[41]::double precision,
					str_data[48]::integer,
					str_data[42]::double precision,
					str_data[43]::double precision,
					str_data[44]::double precision,
					str_data[45]::double precision,
					str_data[46]::double precision,
					str_data[47]::double precision,
					str_data[49]::integer,
					str_data[50]::double precision,
					str_data[51]::double precision,
					str_data[52]::double precision,
					str_data[53],
					str_data[54],
					str_data[55]::integer,
					str_data[56]::integer,
					str_data[57]::integer,
					str_data[58]::integer,
					str_data[59]::integer,
					str_data[60]::integer,
					str_data[61]::double precision,
					str_data[62]::double precision,
					str_data[63],
					str_data[64],
					str_data[67]::boolean,
					str_data[68]::integer,
					now(),
					usuario_id::integer,
					emp_id::integer, 
					suc_id::integer 
				)RETURNING id INTO ultimo_id;
				


			IF trim(str_data[37])<>'' THEN 
				--Si existe el nombre del usuario hay que crear el registro.
				
				--Crea el usuario
				INSERT INTO gral_usr(username,password,enabled,gral_empleados_id)VALUES(str_data[37],str_data[38],str_data[40]::boolean,ultimo_id::integer)
				RETURNING id INTO ultimo_id_usr;
				
				--Asigna sucursal al usuario
				INSERT INTO gral_usr_suc(gral_usr_id,gral_suc_id) VALUES(ultimo_id_usr,str_data[34]::integer);
				
				total_filas:= array_length(extra_data,1);--obtiene total de elementos del arreglo
				cont_fila:=1;
				
				IF extra_data[1]<>'sin datos' THEN
					FOR cont_fila IN 1 .. total_filas LOOP
						SELECT INTO str_filas string_to_array(extra_data[cont_fila],'___');
						--Aqui se vuelven a crear los registros para asignar roles al usuario
						INSERT INTO gral_usr_rol(gral_usr_id,gral_rol_id) VALUES(ultimo_id_usr,extra_data[cont_fila]::integer);
					END LOOP;
				END IF;
			END IF;

			
			--Verificar si incluye NOMINA
			IF incluye_nomina THEN 
				--str_data[65] Percepciones
				IF str_data[65] is not null AND str_data[65]!='' THEN
					--Convertir en arreglo la cadena de Percepciones
					SELECT INTO str_percep string_to_array(str_data[65],',');
					
					FOR iter_y IN array_lower(str_percep,1) .. array_upper(str_percep,1) LOOP
						INSERT INTO gral_empleado_percep(gral_empleado_id,nom_percep_id) VALUES (ultimo_id,str_percep[iter_y]::integer);
					END LOOP;
				END IF;

				--str_data[66] deducciones
				IF str_data[66] is not null AND str_data[66]!='' THEN
					--Convertir en arreglo la cadena de Percepciones
					SELECT INTO str_deduc string_to_array(str_data[66],',');
					
					FOR iter_y IN array_lower(str_deduc,1) .. array_upper(str_deduc,1) LOOP
						INSERT INTO gral_empleado_deduc(gral_empleado_id,nom_deduc_id) VALUES (ultimo_id,str_deduc[iter_y]::integer);
					END LOOP;
				END IF;
			END IF;
			
			valor_retorno := '1';
		END IF;
		
		IF command_selected = 'edit' THEN
			--SELECT INTO str_data string_to_array(''||campos_data||'','___');
			--RAISE EXCEPTION '%',str_data[1];
			--RAISE EXCEPTION '%',identificador;
			UPDATE gral_empleados SET 
				nombre_pila=str_data[5],
				apellido_paterno=str_data[6],
				apellido_materno=str_data[7],
				imss=str_data[8],
				infonavit=str_data[9],
				curp=str_data[10],
				rfc=str_data[11],
				fecha_nacimiento=str_data[12]::date,
				fecha_ingreso=str_data[13]::date,
				gral_escolaridad_id=str_data[14]::integer,
				gral_sexo_id=str_data[15]::integer,
				gral_civil_id=str_data[16]::integer,
				gral_religion_id=str_data[17]::integer,
				gral_sangretipo_id=str_data[30]::integer,
				gral_puesto_id=str_data[33]::integer,
				gral_categ_id=str_data[35]::integer,
				gral_suc_id_empleado=str_data[34]::integer,
				telefono=str_data[18],
				telefono_movil=str_data[19],
				correo_personal=str_data[20],
				gral_pais_id=str_data[21]::integer,
				gral_edo_id=str_data[22]::integer,
				gral_mun_id=str_data[23]::integer,
				calle=str_data[24],
				numero=str_data[25],
				colonia=str_data[26],
				cp=str_data[27],
				contacto_emergencia=str_data[28],
				telefono_emergencia=str_data[29],
				enfermedades=str_data[31],
				alergias=str_data[32],
				comentarios=str_data[36],
				comision_agen=str_data[41]::double precision,
				region_id_agen=str_data[48]::integer,
				comision2_agen=str_data[42]::double precision,
				comision3_agen=str_data[43]::double precision,
				comision4_agen=str_data[44]::double precision,
				dias_tope_comision=str_data[45]::double precision,
				dias_tope_comision2=str_data[46]::double precision,
				dias_tope_comision3=str_data[47]::double precision,
				tipo_comision=str_data[49]::integer,
				monto_tope_comision=str_data[50]::double precision,
				monto_tope_comision2=str_data[51]::double precision,
				monto_tope_comision3=str_data[52]::double precision,
				correo_empresa=str_data[53],
				no_int=str_data[54],
				nom_regimen_contratacion_id=str_data[55]::integer,
				nom_tipo_contrato_id=str_data[56]::integer,
				nom_tipo_jornada_id=str_data[57]::integer,
				nom_periodicidad_pago_id=str_data[58]::integer,
				tes_ban_id=str_data[59]::integer,
				nom_riesgo_puesto_id=str_data[60]::integer,
				salario_base=str_data[61]::double precision,
				salario_integrado=str_data[62]::double precision,
				registro_patronal=str_data[63],
				clabe=str_data[64],
				genera_nomina=str_data[67]::boolean,
				gral_depto_id=str_data[68]::integer,
				momento_actualizacion=now()::timestamp with time zone,
				gral_usr_id_actualizacion=usuario_id
			WHERE id=str_data[4]::integer;
			
			
			IF trim(str_data[37])<>'' THEN 
				IF (SELECT count(id) FROM gral_usr WHERE gral_empleados_id=str_data[4]::integer)<=0 THEN 
					--Crea el usuario
					INSERT INTO gral_usr(username,password,enabled,gral_empleados_id)VALUES(str_data[37],str_data[38],str_data[40]::boolean,str_data[4]::integer)
					RETURNING id INTO ultimo_id_usr;
				ELSE
					UPDATE gral_usr SET username=str_data[37], password=str_data[38], enabled=str_data[40]::boolean
					WHERE gral_empleados_id=str_data[4]::integer RETURNING id INTO ultimo_id_usr;
				END IF;
				
				--Buscar el registro en gral_usr_suc
				SELECT count(id) FROM gral_usr_suc WHERE gral_usr_id=ultimo_id_usr INTO exis;
				
				IF exis > 0 THEN
					--Actualizar la sucursal del usuario
					UPDATE gral_usr_suc SET gral_suc_id=str_data[34]::integer WHERE gral_usr_id=ultimo_id_usr;
				ELSE 
					--Crear registro
					INSERT INTO gral_usr_suc(gral_usr_id, gral_suc_id)VALUES(ultimo_id_usr, str_data[34]::integer);
				END IF;
			ELSE
				IF (SELECT count(id) FROM gral_usr WHERE gral_empleados_id=str_data[4]::integer AND enabled=true)>=0 THEN 
					UPDATE gral_usr SET enabled=false WHERE gral_empleados_id=str_data[4]::integer AND enabled=true;
				END IF;
			END IF;
			
			
			--Elimina todos los roles asignados actualmente
			delete from gral_usr_rol where gral_usr_id=ultimo_id_usr;


			IF trim(str_data[37])<>'' THEN 
				total_filas:= array_length(extra_data,1);--obtiene total de elementos del arreglo
				cont_fila:=1;

				--RAISE EXCEPTION '%','extra_data[1]: '||extra_data[1];
				
				IF extra_data[1]<>'sin_datos' THEN
					FOR cont_fila IN 1 .. total_filas LOOP
						SELECT INTO str_filas string_to_array(extra_data[cont_fila],'___');
						--Aqui se vuelven a crear los registros
						INSERT INTO gral_usr_rol(gral_usr_id,gral_rol_id  )
						VALUES(ultimo_id_usr,extra_data[cont_fila]::integer);
					END LOOP;
				END IF;
			END IF;



			--Verificar si incluye NOMINA
			IF incluye_nomina THEN 
				--Elimina las Percepciones asignadas actualmente
				delete from gral_empleado_percep where gral_empleado_id=str_data[4]::integer;
				
				--str_data[65] Percepciones
				IF str_data[65] is not null AND str_data[65]!='' THEN
					--Convertir en arreglo la cadena de Percepciones
					SELECT INTO str_percep string_to_array(str_data[65],',');
					--Aqui se vuelven a crear registros de las percepciones asignadas
					FOR iter_y IN array_lower(str_percep,1) .. array_upper(str_percep,1) LOOP
						INSERT INTO gral_empleado_percep(gral_empleado_id,nom_percep_id) VALUES (str_data[4]::integer,str_percep[iter_y]::integer);
					END LOOP;
				END IF;


				--Elimina las Deducciones asignadas actualmente
				delete from gral_empleado_deduc where gral_empleado_id=str_data[4]::integer;
				
				--str_data[66] deducciones
				IF str_data[66] is not null AND str_data[66]!='' THEN
					--Convertir en arreglo la cadena de Percepciones
					SELECT INTO str_deduc string_to_array(str_data[66],',');

					--Aqui se vuelven a crear registros de las Deducciones asignadas
					FOR iter_y IN array_lower(str_deduc,1) .. array_upper(str_deduc,1) LOOP
						INSERT INTO gral_empleado_deduc(gral_empleado_id,nom_deduc_id) VALUES (str_data[4]::integer,str_deduc[iter_y]::integer);
					END LOOP;
				END IF;
			END IF;
			
			valor_retorno := '1';
		END IF;
		
		IF command_selected = 'delete' THEN
			UPDATE gral_empleados SET borrado_logico=true,  momento_baja=now(), gral_usr_id_baja=usuario_id::integer 
			WHERE id=str_data[4]::integer;
			
			--Deshabilitar usuario y cambiar el nombre del username, esto para evitar conservar el nombre del usuario.
			--No es posible eliminar el registro porque se utliza como llave foranea en varias tablas
			UPDATE gral_usr SET username='01010101010101010101010101010101010101010101010101', enabled=false WHERE gral_empleados_id=str_data[4]::integer;
			
			valor_retorno := '1';
		END IF;

    END IF;--termina catalogo de empleados


    -- Catalogo de Clientes
    IF app_selected = 5 THEN
		IF command_selected = 'new' THEN

			id_tipo_consecutivo:=1;--Folio de proveedor
			
			--aqui entra para tomar el consecutivo del folio  la sucursal actual
			UPDATE 	gral_cons SET consecutivo=( SELECT sbt.consecutivo + 1  FROM gral_cons AS sbt WHERE sbt.id=gral_cons.id )
			WHERE gral_emp_id=emp_id AND gral_suc_id=suc_id AND gral_cons_tipo_id=id_tipo_consecutivo  RETURNING prefijo,consecutivo INTO prefijo_consecutivo,nuevo_consecutivo;
			
			--concatenamos el prefijo y el nuevo consecutivo para obtener el nuevo folio 
			nuevo_folio := prefijo_consecutivo || nuevo_consecutivo::character varying;
			
			INSERT INTO cxc_clie(
					numero_control,--nuevo_folio
					rfc,--str_data[6]
					curp,--str_data[7]
					razon_social,--str_data[8]
					clave_comercial,--str_data[9]
					calle,--str_data[10]
					numero,--str_data[11]
					entre_calles,--str_data[12]
					numero_exterior,--str_data[13]
					colonia,--str_data[14]
					cp,--str_data[15]
					pais_id,--str_data[16]::integer
					estado_id,--str_data[17]::integer
					municipio_id,--str_data[18]::integer
					localidad_alternativa,--str_data[19]
					telefono1,--str_data[20]
					extension1,--str_data[21]
					fax,--str_data[22]
					telefono2,--str_data[23]
					extension2,--str_data[24]
					email,--str_data[25]
					cxc_agen_id,--str_data[26]::integer
					contacto,--str_data[27]
					zona_id,--str_data[28]::integer
					cxc_clie_grupo_id,--str_data[29]::integer
					clienttipo_id,--str_data[30]::integer
					clasif_1,--str_data[31]::integer
					clasif_2,--str_data[32]::integer
					clasif_3,--str_data[33]::integer
					moneda,--str_data[34]::integer
					filial,--str_data[35]::boolean
					estatus,--str_data[36]::boolean
					gral_imp_id,--str_data[37]::integer
					limite_credito,--str_data[38]::double precision
					dias_credito_id,--str_data[39]::integer
					credito_suspendido,--str_data[40]::boolean
					credito_a_partir,--str_data[41]::integer
					cxp_prov_tipo_embarque_id,--str_data[42]::integer
					dias_caducidad_cotizacion,--str_data[43]::integer
					condiciones,--str_data[44]
					observaciones,--str_data[45]
					contacto_compras_nombre,--str_data[46]
					contacto_compras_puesto,--str_data[47]
					contacto_compras_calle,--str_data[48]
					contacto_compras_numero,--str_data[49]
					contacto_compras_colonia,--str_data[50]
					contacto_compras_cp,--str_data[51]
					contacto_compras_entre_calles,--str_data[52]
					contacto_compras_pais_id,--str_data[53]::integer
					contacto_compras_estado_id,--str_data[54]::integer
					contacto_compras_municipio_id,--str_data[55]::integer
					contacto_compras_telefono1,--str_data[56]
					contacto_compras_extension1,--str_data[57]
					contacto_compras_fax,--str_data[58]
					contacto_compras_telefono2,--str_data[59]
					contacto_compras_extension2,--str_data[60]
					contacto_compras_email,--str_data[61]
					contacto_pagos_nombre,--str_data[62]
					contacto_pagos_puesto,--str_data[63]
					contacto_pagos_calle,--str_data[64]
					contacto_pagos_numero,--str_data[65]
					contacto_pagos_colonia,--str_data[66]
					contacto_pagos_cp,--str_data[67]
					contacto_pagos_entre_calles,--str_data[68]
					contacto_pagos_pais_id,--str_data[69]::integer
					contacto_pagos_estado_id,--str_data[70]::integer
					contacto_pagos_municipio_id,--str_data[71]::integer
					contacto_pagos_telefono1,--str_data[72]
					contacto_pagos_extension1,--str_data[73]
					contacto_pagos_fax,--str_data[74]
					contacto_pagos_telefono2,--str_data[75]
					contacto_pagos_extension2,--str_data[76]
					contacto_pagos_email,--str_data[77]
					empresa_immex,--str_data[78]::boolean,
					tasa_ret_immex,--str_data[79]::double precision,
					dia_revision,--str_data[80]::smallint,
					dia_pago,--str_data[81]::smallint,
					cta_pago_mn,--str_data[82],
					cta_pago_usd,--str_data[83],
					ctb_cta_id_activo,--str_data[84]::integer,
					ctb_cta_id_ingreso,--str_data[85]::integer,
					ctb_cta_id_ietu,--str_data[86]::integer,
					ctb_cta_id_comple,--str_data[87]::integer,
					ctb_cta_id_activo_comple,--str_data[88]::integer,
					lista_precio,--str_data[89]::integer,
					fac_metodos_pago_id,--str_data[90]::integer,
					empresa_id,--emp_id
					sucursal_id,--suc_id
					borrado_logico,--false
					momento_creacion,--now()
					id_usuario_creacion--usuario_id
				)VALUES (
					nuevo_folio,
					str_data[6],
					str_data[7],
					str_data[8],
					str_data[9],
					str_data[10],
					str_data[11],
					str_data[12],
					str_data[13],
					str_data[14],
					str_data[15],
					str_data[16]::integer,
					str_data[17]::integer,
					str_data[18]::integer,
					str_data[19],
					str_data[20],
					str_data[21],
					str_data[22],
					str_data[23],
					str_data[24],
					str_data[25],
					str_data[26]::integer,
					str_data[27],
					str_data[28]::integer,
					str_data[29]::integer,
					str_data[30]::integer,
					str_data[31]::integer,
					str_data[32]::integer,
					str_data[33]::integer,
					str_data[34]::integer,
					str_data[35]::boolean,
					str_data[36]::boolean,
					str_data[37]::integer,
					str_data[38]::double precision,
					str_data[39]::integer,
					str_data[40]::boolean,
					str_data[41]::integer,
					str_data[42]::integer,
					str_data[43]::integer,
					str_data[44],
					str_data[45],
					str_data[46],
					str_data[47],
					str_data[48],
					str_data[49],
					str_data[50],
					str_data[51],
					str_data[52],
					str_data[53]::integer,
					str_data[54]::integer,
					str_data[55]::integer,
					str_data[56],
					str_data[57],
					str_data[58],
					str_data[59],
					str_data[60],
					str_data[61],
					str_data[62],
					str_data[63],
					str_data[64],
					str_data[65],
					str_data[66],
					str_data[67],
					str_data[68],
					str_data[69]::integer,
					str_data[70]::integer,
					str_data[71]::integer,
					str_data[72],
					str_data[73],
					str_data[74],
					str_data[75],
					str_data[76],
					str_data[77],
					str_data[78]::boolean,
					str_data[79]::double precision,
					str_data[80]::smallint,
					str_data[81]::smallint,
					str_data[82],
					str_data[83],
					str_data[84]::integer,
					str_data[85]::integer,
					str_data[86]::integer,
					str_data[87]::integer,
					str_data[88]::integer,
					str_data[89]::integer,
					str_data[90]::integer,
					emp_id,
					suc_id,
					false,
					now(),
					usuario_id
				)RETURNING id INTO ultimo_id;
			
				
			
			total_filas:= array_length(extra_data,1);--obtiene total de elementos del arreglo
			cont_fila:=1;
			
			IF extra_data[1] != 'sin datos' THEN
				FOR cont_fila IN 1 .. total_filas LOOP
					SELECT INTO str_filas string_to_array(extra_data[cont_fila],'___');
					--str_filas[1] calle
					--str_filas[2] numero
					--str_filas[3] colonia
					--str_filas[4] idpais
					--str_filas[5] identidad
					--str_filas[6] idlocalidad
					--str_filas[7] codigop
					--str_filas[8] localternativa
					--str_filas[9] telefono
					--str_filas[10] numfax
					
					INSERT INTO erp_clients_consignacions(cliente_id, calle, numero, colonia, pais_id, estado_id, municipio_id, cp, localidad_alternativa, telefono, fax, momento_creacion)
					VALUES(ultimo_id, str_filas[1], str_filas[2], str_filas[3], str_filas[4]::integer, str_filas[5]::integer, str_filas[6]::integer, str_filas[7], str_filas[8], str_filas[9], str_filas[10], now());
					
				END LOOP;
				
			END IF;
			
			valor_retorno := '1';
		END IF;
		
		IF command_selected = 'edit' THEN

			UPDATE cxc_clie SET 
					rfc=str_data[6],
					curp=str_data[7],
					razon_social=str_data[8],
					clave_comercial=str_data[9],
					calle=str_data[10],
					numero=str_data[11],
					entre_calles=str_data[12],
					numero_exterior=str_data[13],
					colonia=str_data[14],
					cp=str_data[15],
					pais_id=str_data[16]::integer,
					estado_id=str_data[17]::integer,
					municipio_id=str_data[18]::integer,
					localidad_alternativa=str_data[19],
					telefono1=str_data[20],
					extension1=str_data[21],
					fax=str_data[22],
					telefono2=str_data[23],
					extension2=str_data[24],
					email=str_data[25],
					cxc_agen_id=str_data[26]::integer,
					contacto=str_data[27],
					zona_id=str_data[28]::integer,
					cxc_clie_grupo_id=str_data[29]::integer,
					clienttipo_id=str_data[30]::integer,
					clasif_1=str_data[31]::integer,
					clasif_2=str_data[32]::integer,
					clasif_3=str_data[33]::integer,
					moneda=str_data[34]::integer,
					filial=str_data[35]::boolean,
					estatus=str_data[36]::boolean,
					gral_imp_id=str_data[37]::integer,
					limite_credito=str_data[38]::double precision,
					dias_credito_id=str_data[39]::integer,
					credito_suspendido=str_data[40]::boolean,
					credito_a_partir=str_data[41]::integer,
					cxp_prov_tipo_embarque_id=str_data[42]::integer,
					dias_caducidad_cotizacion=str_data[43]::integer,
					condiciones=str_data[44],
					observaciones=str_data[45],
					contacto_compras_nombre=str_data[46],
					contacto_compras_puesto=str_data[47],
					contacto_compras_calle=str_data[48],
					contacto_compras_numero=str_data[49],
					contacto_compras_colonia=str_data[50],
					contacto_compras_cp=str_data[51],
					contacto_compras_entre_calles=str_data[52],
					contacto_compras_pais_id=str_data[53]::integer,
					contacto_compras_estado_id=str_data[54]::integer,
					contacto_compras_municipio_id=str_data[55]::integer,
					contacto_compras_telefono1=str_data[56],
					contacto_compras_extension1=str_data[57],
					contacto_compras_fax=str_data[58],
					contacto_compras_telefono2=str_data[59],
					contacto_compras_extension2=str_data[60],
					contacto_compras_email=str_data[61],
					contacto_pagos_nombre=str_data[62],
					contacto_pagos_puesto=str_data[63],
					contacto_pagos_calle=str_data[64],
					contacto_pagos_numero=str_data[65],
					contacto_pagos_colonia=str_data[66],
					contacto_pagos_cp=str_data[67],
					contacto_pagos_entre_calles=str_data[68],
					contacto_pagos_pais_id=str_data[69]::integer,
					contacto_pagos_estado_id=str_data[70]::integer,
					contacto_pagos_municipio_id=str_data[71]::integer,
					contacto_pagos_telefono1=str_data[72],
					contacto_pagos_extension1=str_data[73],
					contacto_pagos_fax=str_data[74],
					contacto_pagos_telefono2=str_data[75],
					contacto_pagos_extension2=str_data[76],
					contacto_pagos_email=str_data[77],
					empresa_immex=str_data[78]::boolean,
					tasa_ret_immex=str_data[79]::double precision,
					dia_revision=str_data[80]::smallint,
					dia_pago=str_data[81]::smallint,
					cta_pago_mn=str_data[82],
					cta_pago_usd=str_data[83],
					ctb_cta_id_activo=str_data[84]::integer,
					ctb_cta_id_ingreso=str_data[85]::integer,
					ctb_cta_id_ietu=str_data[86]::integer,
					ctb_cta_id_comple=str_data[87]::integer,
					ctb_cta_id_activo_comple=str_data[88]::integer,
					lista_precio=str_data[89]::integer,
					fac_metodos_pago_id=str_data[90]::integer,
					momento_actualizacion = now(),
					id_usuario_actualizacion = usuario_id,
					empresa_id=emp_id,
					sucursal_id=suc_id
			WHERE id=str_data[4]::integer;
			
			--eliminar direcciones de este cliente en la tabla clients_consignacions
			DELETE FROM erp_clients_consignacions WHERE cliente_id = str_data[4]::integer;
			
			total_filas:= array_length(extra_data,1);--obtiene total de elementos del arreglo
			cont_fila:=1;
			
			IF extra_data[1] != 'sin datos' THEN
				FOR cont_fila IN 1 .. total_filas LOOP
					SELECT INTO str_filas string_to_array(extra_data[cont_fila],'___');
					--aqui se vuelven a crear los registros
					INSERT INTO erp_clients_consignacions(cliente_id,calle,numero,colonia,pais_id,estado_id,municipio_id,cp,localidad_alternativa,telefono,fax,momento_creacion)
					VALUES(str_data[3]::integer,str_filas[1],str_filas[2],str_filas[3],str_filas[4]::integer,str_filas[5]::integer,str_filas[6]::integer,str_filas[7],str_filas[8],str_filas[9],str_filas[10],now());
					
				END LOOP;
				
			END IF;
			
			valor_retorno := '1';
		END IF;
		
		IF command_selected = 'delete' THEN
			UPDATE cxc_clie SET borrado_logico=true, momento_baja=now(),id_usuario_baja = str_data[3]::integer WHERE id = str_data[4]::integer;
			valor_retorno := '1';
		END IF;

    END IF;--termina catalogo de clientes
	

    -- Catalogo de Proveedores
    IF app_selected = 2 THEN
		IF command_selected = 'new' THEN

			id_tipo_consecutivo:=2;--Folio de proveedor
			
			--aqui entra para tomar el consecutivo del folio  la sucursal actual
			UPDATE 	gral_cons SET consecutivo=( SELECT sbt.consecutivo + 1  FROM gral_cons AS sbt WHERE sbt.id=gral_cons.id )
			WHERE gral_emp_id=emp_id AND gral_suc_id=suc_id AND gral_cons_tipo_id=id_tipo_consecutivo  RETURNING prefijo,consecutivo INTO prefijo_consecutivo,nuevo_consecutivo;
			
			--concatenamos el prefijo y el nuevo consecutivo para obtener el nuevo folio 
			nuevo_folio := prefijo_consecutivo || nuevo_consecutivo::character varying;

			INSERT INTO cxp_prov(
				folio,--nuevo_folio
				rfc,--str_data[6]
				curp,--str_data[7]
				razon_social,--str_data[8]
				clave_comercial,--str_data[9]
				calle,--str_data[10]
				numero,--str_data[11]
				colonia,--str_data[12]
				cp,--str_data[13]
				entre_calles,--str_data[14]
				pais_id,--str_data[15]::integer
				estado_id,--str_data[16]::integer
				municipio_id,--str_data[17]::integer
				localidad_alternativa,--str_data[18]
				telefono1,--str_data[19]
				extension1,--str_data[20]
				fax,--str_data[21]
				telefono2,--str_data[22]
				extension2,--str_data[23]
				correo_electronico,--str_data[24]
				web_site,--str_data[25]
				impuesto,--str_data[26]::integer
				cxp_prov_zona_id,--str_data[27]::integer
				grupo_id,--str_data[28]::integer
				proveedortipo_id,--str_data[29]::integer
				clasif_1,--str_data[30]::integer
				clasif_2,--str_data[31]::integer
				clasif_3,--str/controllers/facturas/startup.agnux_data[32]::integer
				moneda_id,--str_data[33]::integer
				tiempo_entrega_id,--str_data[34]::integer
				estatus,--str_data[35]::boolean
				limite_credito,--str_data[36]::double precision
				dias_credito_id,--str_data[37]::integer
				descuento,--str_data[38]::double precision
				credito_a_partir,--str_data[39]::integer
				cxp_prov_tipo_embarque_id,--str_data[40]::integer
				flete_pagado,--str_data[41]::boolean
				condiciones,--str_data[42]
				observaciones,--str_data[43]
				vent_contacto,--str_data[44]
				vent_puesto,--str_data[45]
				vent_calle,--str_data[46]
				vent_numero,--/controllers/facturas/startup.agnuxstr_data[47]
				vent_colonia,--str_data[48]
				vent_cp,--str_data[49]
				vent_entre_calles,--str_data[50]
				vent_pais_id,--str_data[51]::integer
				vent_estado_id,--str_data[52]::integer
				vent_municipio_id,--str_data[53]::integer
				vent_telefono1,--str_data[54]
				vent_extension1,--str_data[55]
				vent_fax,--str_data[56]
				vent_telefono2,--str_data[57]
				vent_extension2,--str_data[58]
				vent_email,--str_data[59]
				cob_contacto,--str_data[60]
				cob_puesto,--str_data[61]
				cob_calle,--str_data[62]
				cob_numero,--str_data[63]
				cob_colonia,--str_data[64]
				cob_cp,--str_data[65]
				cob_entre_calles,--str_data[66]
				cob_pais_id,--str_data[67]::integer
				cob_estado_id,--str_data[68]::integer
				cob_municipio_id,--str_data[69]::integer
				cob_telefono1,--str_data[70]
				cob_extension1,--str_data[71]
				cob_fax,--str_data[72]
				cob_telefono2,--str_data[73]
				cob_extension2,--str_data[74]
				cob_email,--str_data[75]
				comentarios,--str_data[76]
				ctb_cta_id_pasivo,--str_data[77]::integer,
				ctb_cta_id_egreso,--str_data[78]::integer,
				ctb_cta_id_ietu,--str_data[79]::integer,
				ctb_cta_id_comple,--str_data[80]::integer,
				ctb_cta_id_pasivo_comple,--str_data[81]::integer,
				transportista,--str_data[82]::boolean,
				empresa_id,--emp_id
				sucursal_id,--suc_id
				borrado_logico,--false,
				momento_creacion,--now()
				id_usuario_creacion--usuario_id
			)
			VALUES(nuevo_folio,str_data[6],str_data[7],str_data[8],str_data[9],str_data[10],str_data[11],str_data[12],str_data[13],str_data[14],str_data[15]::integer,str_data[16]::integer,str_data[17]::integer,str_data[18],str_data[19],str_data[20],str_data[21],str_data[22],str_data[23],str_data[24],str_data[25],str_data[26]::integer,str_data[27]::integer,str_data[28]::integer,str_data[29]::integer,str_data[30]::integer,str_data[31]::integer,str_data[32]::integer,str_data[33]::integer,str_data[34]::integer,str_data[35]::boolean,str_data[36]::double precision,str_data[37]::integer,str_data[38]::double precision,str_data[39]::integer,str_data[40]::integer,str_data[41]::boolean,str_data[42],str_data[43],str_data[44],str_data[45],str_data[46],str_data[47],str_data[48],str_data[49],str_data[50],str_data[51]::integer,str_data[52]::integer,str_data[53]::integer,str_data[54],str_data[55],str_data[56],str_data[57],str_data[58],str_data[59],str_data[60],str_data[61],str_data[62],str_data[63],str_data[64],str_data[65],str_data[66],str_data[67]::integer,str_data[68]::integer,str_data[69]::integer,str_data[70],str_data[71],str_data[72],str_data[73],str_data[74],str_data[75],str_data[76], str_data[77]::integer, str_data[78]::integer, str_data[79]::integer, str_data[80]::integer, str_data[81]::integer, str_data[82]::boolean, emp_id, suc_id, false, now(), usuario_id);
			
			valor_retorno := '1';
		END IF;

		
		IF command_selected = 'edit' THEN 

			UPDATE cxp_prov SET rfc=str_data[6],curp=str_data[7],razon_social=str_data[8],clave_comercial=str_data[9],calle=str_data[10],numero=str_data[11],colonia=str_data[12],cp=str_data[13],entre_calles=str_data[14],pais_id=str_data[15]::integer,estado_id=str_data[16]::integer,municipio_id=str_data[17]::integer,localidad_alternativa=str_data[18],telefono1=str_data[19],extension1=str_data[20],fax=str_data[21],telefono2=str_data[22],extension2=str_data[23],correo_electronico=str_data[24],web_site=str_data[25],impuesto=str_data[26]::integer,cxp_prov_zona_id=str_data[27]::integer,grupo_id=str_data[28]::integer,proveedortipo_id=str_data[29]::integer,clasif_1=str_data[30]::integer,clasif_2=str_data[31]::integer,clasif_3=str_data[32]::integer,moneda_id=str_data[33]::integer,tiempo_entrega_id=str_data[34]::integer,estatus=str_data[35]::boolean,limite_credito=str_data[36]::double precision,dias_credito_id=str_data[37]::integer,
				descuento=str_data[38]::double precision,credito_a_partir=str_data[39]::integer,cxp_prov_tipo_embarque_id=str_data[40]::integer,flete_pagado=str_data[41]::boolean,condiciones=str_data[42],observaciones=str_data[43],vent_contacto=str_data[44],vent_puesto=str_data[45],vent_calle=str_data[46],vent_numero=str_data[47],vent_colonia=str_data[48],vent_cp=str_data[49],vent_entre_calles=str_data[50],vent_pais_id=str_data[51]::integer,vent_estado_id=str_data[52]::integer,vent_municipio_id=str_data[53]::integer,vent_telefono1=str_data[54],vent_extension1=str_data[55],vent_fax=str_data[56],vent_telefono2=str_data[57],vent_extension2=str_data[58],vent_email=str_data[59],cob_contacto=str_data[60],cob_puesto=str_data[61],cob_calle=str_data[62],cob_numero=str_data[63],cob_colonia=str_data[64],cob_cp=str_data[65],cob_entre_calles=str_data[66],cob_pais_id=str_data[67]::integer,cob_estado_id=str_data[68]::integer,cob_municipio_id=str_data[69]::integer,
				cob_telefono1=str_data[70],cob_extension1=str_data[71],cob_fax=str_data[72],cob_telefono2=str_data[73],cob_extension2=str_data[74],cob_email=str_data[75],comentarios=str_data[76], ctb_cta_id_pasivo=str_data[77]::integer, ctb_cta_id_egreso=str_data[78]::integer, ctb_cta_id_ietu=str_data[79]::integer, ctb_cta_id_comple=str_data[80]::integer, ctb_cta_id_pasivo_comple=str_data[81]::integer, transportista=str_data[82]::boolean, momento_actualizacion=now(),id_usuario_actualizacion=usuario_id
			WHERE id = str_data[4]::integer;
			valor_retorno := '1';
		END IF;
		
		IF command_selected = 'delete' THEN
			UPDATE cxp_prov SET borrado_logico=true, momento_baja=now(), id_usuario_baja=usuario_id WHERE id=str_data[4]::integer;
			valor_retorno := '1';
		END IF;
    END IF;
    --Termina catalogo de proveedores


    -- Catalogo de Productos
    IF app_selected = 8 THEN
		
		IF str_data[15]::integer=0 THEN
			meta_imp:='exento';
		END IF;
		IF str_data[15]::integer=1 THEN
			meta_imp:='iva_1';
		END IF;
		IF str_data[15]::integer=2 THEN
			meta_imp:='tasa_cero';
		END IF;
		
		--query para verificar si la Empresa actual incluye Modulo de Produccion, Modulo de Contabilidad y Modulo de Envasado
		SELECT incluye_produccion, incluye_contabilidad, encluye_envasado FROM gral_emp WHERE id=emp_id INTO incluye_modulo_produccion, incluye_modulo_contabilidad, incluye_modulo_envasado;
		
		IF command_selected = 'new' THEN
			id_tipo_consecutivo:=3;--Folio de pproducto

			--alter para catalogo productos
			--ALTER TABLE inv_prod ADD COLUMN archivo_pdf character varying DEFAULT '';
			
			--aqui entra para tomar el consecutivo del folio  la sucursal actual
			--UPDATE 	gral_cons SET consecutivo=( SELECT sbt.consecutivo + 1  FROM gral_cons AS sbt WHERE sbt.id=gral_cons.id )
			--WHERE gral_emp_id=emp_id AND gral_suc_id=suc_id AND gral_cons_tipo_id=id_tipo_consecutivo  RETURNING prefijo,consecutivo INTO prefijo_consecutivo,nuevo_consecutivo;
			
			--concatenamos el prefijo y el nuevo consecutivo para obtener el nuevo folio 
			--nuevo_folio := prefijo_consecutivo || nuevo_consecutivo::character varying;
			nuevo_folio := str_data[31];
			tipo_producto:=str_data[18]::integer;
			INSERT INTO inv_prod(	
				sku,--nuevo_folio
				descripcion,--str_data[5]
				codigo_barras,--str_data[6]
				tentrega,--str_data[7]::integer,
				inv_clas_id,--str_data[8]::integer
				inv_stock_clasif_id,--str_data[9]::integer
				estatus,--str_data[10]::boolean
				inv_prod_familia_id,--str_data[11]::integer
				subfamilia_id,--str_data[12]::integer
				inv_prod_grupo_id,--str_data[13]::integer
				ieps,--str_data[14]::integer
				--meta_impuesto,--meta_imp
				gral_impto_id,--str_data[15]::integer,
				inv_prod_linea_id,--str_data[16]::integer
				inv_mar_id,--str_data[17]::integer
				tipo_de_producto_id,--str_data[18]::integer
				inv_seccion_id,--str_data[19]::integer
				unidad_id,--str_data[20]::integer
				requiere_numero_lote,--str_data[21]::boolean
				requiere_nom,--str_data[22]::boolean
				requiere_numero_serie,--str_data[23]::boolean
				requiere_pedimento,--str_data[24]::boolean
				permitir_stock,--str_data[25]::boolean
				venta_moneda_extranjera,--str_data[26]::boolean
				compra_moneda_extranjera,--str_data[27]::boolean
				cxp_prov_id,--str_data[29]::integer
				densidad,--str_data[30]::double precision
				valor_maximo,--str_data[32]::double precision
				valor_minimo,--str_data[33]::double precision
				punto_reorden,--str_data[34]::double precision
				ctb_cta_id_gasto, --str_data[35]::integer,
				ctb_cta_id_costo_venta, --str_data[36]::integer,
				ctb_cta_id_venta, --str_data[37]::integer,
				borrado_logico,--false
				momento_creacion,--now()
				id_usuario_creacion,--usuario_id
				empresa_id,--emp_id
				sucursal_id,--suc_id
				descripcion_corta,--str_data[40]
				descripcion_larga,--str_data[41]
				archivo_img,--str_data[38]
				archivo_pdf,--str_data[39]
				inv_prod_presentacion_id,--str_data[42]::integer
				flete,--str_data[43]::boolean,
				no_clie,--str_data[44]
				gral_mon_id,--str_data[45]::integer
				gral_imptos_ret_id --str_data[46]::integer
			) values(
				nuevo_folio,
				str_data[5],
				str_data[6],
				str_data[7]::integer,
				str_data[8]::integer,
				str_data[9]::integer,
				str_data[10]::boolean,
				str_data[11]::integer,
				str_data[12]::integer,
				str_data[13]::integer,
				str_data[14]::integer,
				--meta_imp,
				str_data[15]::integer,
				str_data[16]::integer,
				str_data[17]::integer,
				str_data[18]::integer,
				str_data[19]::integer,
				str_data[20]::integer,
				str_data[21]::boolean,
				str_data[22]::boolean,
				str_data[23]::boolean,
				str_data[24]::boolean,
				str_data[25]::boolean,
				str_data[26]::boolean,
				str_data[27]::boolean,
				str_data[29]::integer,
				str_data[30]::double precision,
				str_data[32]::double precision,
				str_data[33]::double precision,
				str_data[34]::double precision,
				str_data[35]::integer,
				str_data[36]::integer,
				str_data[37]::integer,
				false,
				now(),
				usuario_id,
				emp_id,
				suc_id,
				str_data[40],
				str_data[41],
				str_data[38],
				str_data[39],
				str_data[42]::integer,
				str_data[43]::boolean,
				str_data[44],
				str_data[45]::integer,
				str_data[46]::integer
			)RETURNING id INTO id_producto;
			
			--convertir en arreglo los id de presentaciones de producto
			SELECT INTO str_pres string_to_array(str_data[28],',');
			
			--obtiene numero de elementos del arreglo str_pres
			tot_filas:= array_length(str_pres,1);
			
			
			--Si el tiopo de producto es diferente de 3 y 4, hay que guardar presentaciones
			--tipo=3 Kit
			--tipo=4 Servicios
			--IF str_data[18]::integer!=3 AND str_data[18]::integer!=4 THEN
				
				FOR cont_fila_pres IN 1 .. tot_filas LOOP
					--Crea registros de presentaciones  en tabla inv_prod_pres_x_prod
					INSERT INTO inv_prod_pres_x_prod(producto_id,presentacion_id) VALUES (id_producto,str_pres[cont_fila_pres]::integer);
					
					--Crea registro por cada presentacion en la tabla de precios 
					INSERT INTO inv_pre (gral_emp_id, inv_prod_id, inv_prod_presentacion_id, momento_creacion,borrado_logico,precio_1, precio_2, precio_3, precio_4, precio_5, precio_6, precio_7, precio_8, precio_9, precio_10, gral_mon_id_pre1, gral_mon_id_pre2, gral_mon_id_pre3, gral_mon_id_pre4, gral_mon_id_pre5, gral_mon_id_pre6, gral_mon_id_pre7, gral_mon_id_pre8, gral_mon_id_pre9, gral_mon_id_pre10, descuento_1,descuento_2,descuento_3,descuento_4,descuento_5,descuento_6,descuento_7,descuento_8,descuento_9,descuento_10,default_precio_1,default_precio_2,default_precio_3,default_precio_4,default_precio_5,default_precio_6,default_precio_7,default_precio_8,default_precio_9,default_precio_10,operacion_precio_1,operacion_precio_2,operacion_precio_3,operacion_precio_4,operacion_precio_5,operacion_precio_6,operacion_precio_7,operacion_precio_8,operacion_precio_9,operacion_precio_10,calculo_precio_1,calculo_precio_2,calculo_precio_3,calculo_precio_4,calculo_precio_5,calculo_precio_6,calculo_precio_7,calculo_precio_8,calculo_precio_9,calculo_precio_10,redondeo_precio_1,redondeo_precio_2,redondeo_precio_3,redondeo_precio_4,redondeo_precio_5,redondeo_precio_6,redondeo_precio_7,redondeo_precio_8,redondeo_precio_9,redondeo_precio_10) 
					VALUES(emp_id, id_producto,str_pres[cont_fila_pres]::integer, now(), false, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0,0,0,0,0,0,0,0,0,0 ,0,0,0,0,0,0,0,0,0,0,  1,1,1,1,1,1,1,1,1,1 ,1,1,1,1,1,1,1,1,1,1,  0,0,0,0,0,0,0,0,0,0);
				END LOOP;
			--END IF;
			
			IF incluye_modulo_produccion=TRUE THEN 
				--para Producto 3=Kit
				IF tipo_producto=3 THEN
					total_filas:= array_length(extra_data,1);
					cont_fila:=1;
					IF extra_data[1]<>'sin datos' THEN
						FOR cont_fila IN 1 .. total_filas LOOP
							SELECT INTO str_filas string_to_array(extra_data[cont_fila],'___');
							--str_filas[1] eliminado
							IF str_filas[1]::integer != 0 THEN--1: no esta eliminado, 0:eliminado
								--ya no se valida nada
								--str_filas[1]	producto_ingrediente_id
								--str_filas[2] 	porcentaje
								--INSERT INTO inv_prod_formulaciones(producto_formulacion_id,producto_ingrediente_id,porcentaje) VALUES (id_producto,str_filas[1]::integer,str_filas[2]::double precision);
								INSERT INTO inv_kit(producto_kit_id,producto_elemento_id,cantidad) 
								VALUES (id_producto,str_filas[1]::integer,str_filas[2]::double precision);
							END IF;
						END LOOP;
					END IF;
				END IF;	
			ELSE
				--para Producto 1=TERMINADO, 2=INTERMEDIO, 3=KIT, 8=DESARROLLO
				IF tipo_producto=1 OR tipo_producto=2 OR tipo_producto=3 OR tipo_producto=8 THEN 
					total_filas:= array_length(extra_data,1);
					cont_fila:=1;
					IF extra_data[1]<>'sin datos' THEN
						FOR cont_fila IN 1 .. total_filas LOOP
							SELECT INTO str_filas string_to_array(extra_data[cont_fila],'___');
							--str_filas[1] eliminado
							IF str_filas[1]::integer != 0 THEN--1: no esta eliminado, 0:eliminado
								--ya no se valida nada
								--str_filas[1]	producto_ingrediente_id
								--str_filas[2] 	porcentaje
								--INSERT INTO inv_prod_formulaciones(producto_formulacion_id,producto_ingrediente_id,porcentaje) VALUES (id_producto,str_filas[1]::integer,str_filas[2]::double precision);
								INSERT INTO inv_kit(producto_kit_id,producto_elemento_id,cantidad) VALUES(id_producto,str_filas[1]::integer,str_filas[2]::double precision);
							END IF;
						END LOOP;
					END IF;
				END IF;
			END IF;
			
			
			--Si el tipo de producto es DIFERENTE DE 3=Kit Y 4=Servicios
			IF str_data[18]::integer<>3 AND str_data[18]::integer<>4 THEN
				--Genera registro en la tabla inv_exi
				FOR fila2 IN EXECUTE('SELECT distinct inv_suc_alm.almacen_id FROM gral_suc JOIN inv_suc_alm ON inv_suc_alm.sucursal_id=gral_suc.id WHERE gral_suc.empresa_id='||emp_id||' ORDER BY inv_suc_alm.almacen_id') LOOP
					INSERT INTO inv_exi(inv_prod_id, inv_alm_id, ano, exi_inicial, transito) VALUES(id_producto, fila2.almacen_id, ano_actual, 0, 0);
				END LOOP;
				
				if str_data[45]::integer=1 then 
					--Si es MN, el tipo de cambio es 1
					valor1:=1;
				else
					--Buscar el tipo de cambio del día
					SELECT valor AS tipo_cambio FROM erp_monedavers WHERE momento_creacion<=now() AND moneda_id=str_data[45]::integer ORDER BY momento_creacion DESC LIMIT 1 into valor1;
					if valor1 is null then valor1:=1; end if;
				end if;
				
				--Genera registro en la tabla 
				INSERT INTO inv_prod_cost_prom(inv_prod_id, ano,gral_mon_id_1,gral_mon_id_2,gral_mon_id_3,gral_mon_id_4,gral_mon_id_5,gral_mon_id_6,gral_mon_id_7,gral_mon_id_8,gral_mon_id_9,gral_mon_id_10,gral_mon_id_11,gral_mon_id_12,tipo_cambio_1,tipo_cambio_2,tipo_cambio_3,tipo_cambio_4,tipo_cambio_5,tipo_cambio_6,tipo_cambio_7,tipo_cambio_8,tipo_cambio_9,tipo_cambio_10,tipo_cambio_11,tipo_cambio_12) 
				VALUES(id_producto, ano_actual,str_data[45]::integer,str_data[45]::integer,str_data[45]::integer,str_data[45]::integer,str_data[45]::integer,str_data[45]::integer,str_data[45]::integer,str_data[45]::integer,str_data[45]::integer,str_data[45]::integer,str_data[45]::integer,str_data[45]::integer,valor1,valor1,valor1,valor1,valor1,valor1,valor1,valor1,valor1,valor1,valor1,valor1);
			END IF;
			
			valor_retorno := '1';
		END IF;--termina nuevo producto
		
		
		IF command_selected = 'edit' THEN
			nuevo_folio := str_data[31];
			tipo_producto:=str_data[18]::integer;
			UPDATE inv_prod SET 
				sku=nuevo_folio,--nuevo_folio, 
				descripcion=str_data[5],
				codigo_barras=str_data[6],
				tentrega=str_data[7]::integer,
				inv_clas_id=str_data[8]::integer,
				inv_stock_clasif_id=str_data[9]::integer,
				estatus=str_data[10]::boolean,
				inv_prod_familia_id=str_data[11]::integer,
				subfamilia_id=str_data[12]::integer,
				inv_prod_grupo_id=str_data[13]::integer,
				ieps=str_data[14]::integer,
				--meta_impuesto=meta_imp,
				gral_impto_id=str_data[15]::integer,
				inv_prod_linea_id=str_data[16]::integer,
				inv_mar_id=str_data[17]::integer,
				tipo_de_producto_id=str_data[18]::integer,
				inv_seccion_id=str_data[19]::integer,
				unidad_id=str_data[20]::integer,
				requiere_numero_lote=str_data[21]::boolean,
				requiere_nom=str_data[22]::boolean,
				requiere_numero_serie=str_data[23]::boolean,
				requiere_pedimento=str_data[24]::boolean,
				permitir_stock=str_data[25]::boolean,
				venta_moneda_extranjera=str_data[26]::boolean,
				compra_moneda_extranjera=str_data[27]::boolean,
				cxp_prov_id=str_data[29]::integer,
				densidad=str_data[30]::double precision,
				valor_maximo=str_data[32]::double precision,
				valor_minimo=str_data[33]::double precision,
				punto_reorden=str_data[34]::double precision,
				ctb_cta_id_gasto=str_data[35]::integer,
				ctb_cta_id_costo_venta=str_data[36]::integer,
				ctb_cta_id_venta=str_data[37]::integer,
				momento_actualizacion=now(),
				id_usuario_actualizacion=usuario_id,
				descripcion_corta=str_data[40],
				descripcion_larga=str_data[41],
				archivo_img=str_data[38],
				archivo_pdf=str_data[39],
				inv_prod_presentacion_id=str_data[42]::integer,
				flete=str_data[43]::boolean,
				no_clie=str_data[44],
				gral_mon_id=str_data[45]::integer,
				gral_imptos_ret_id=str_data[46]::integer 
			WHERE id=str_data[4]::integer;
			
			--convertir en arreglo los id de presentaciones de producto
			SELECT INTO str_pres string_to_array(str_data[28],',');
			
			--obtiene numero de elementos del arreglo str_pres
			tot_filas:= array_length(str_pres,1);
			
			--elimina los registros de las presentaciones del producto
			DELETE FROM inv_prod_pres_x_prod WHERE producto_id=str_data[4]::integer;
			
			--Si el tiopo de producto es diferente de 3 y 4, hay que guardar presentaciones
			--tipo=3 Kit
			--tipo=4 Servicios
			--IF str_data[18]::integer!=3 AND str_data[18]::integer!=4 THEN
				--aqui se vuelven a crear los registros de las presentaciones del producto
				FOR cont_fila_pres IN 1 .. tot_filas LOOP
					INSERT INTO inv_prod_pres_x_prod(producto_id,presentacion_id) VALUES (str_data[4]::integer,str_pres[cont_fila_pres]::integer);
				END LOOP;
			--END IF;
			
			FOR fila IN EXECUTE('SELECT id, inv_prod_id, inv_prod_presentacion_id FROM inv_prod_costos WHERE inv_prod_id='||str_data[4]::integer||' AND ano=EXTRACT(YEAR FROM now())') LOOP
				exis:=0;
				SELECT count(id) FROM inv_prod_pres_x_prod WHERE producto_id=fila.inv_prod_id AND presentacion_id=fila.inv_prod_presentacion_id INTO exis;
				IF exis<=0 THEN 
					DELETE FROM inv_prod_costos WHERE id=fila.id;
				END IF;
			END LOOP;
			
			FOR fila IN EXECUTE('SELECT id, inv_prod_id, inv_prod_presentacion_id FROM inv_pre WHERE inv_prod_id='||str_data[4]::integer||' AND gral_emp_id='||emp_id) LOOP
				exis:=0;
				SELECT count(id) FROM inv_prod_pres_x_prod WHERE producto_id=fila.inv_prod_id AND presentacion_id=fila.inv_prod_presentacion_id INTO exis;
				IF exis<=0 THEN 
					DELETE FROM inv_pre WHERE id=fila.id;
				END IF;
			END LOOP;
			
			IF controlExisPres THEN 
				FOR fila IN EXECUTE('SELECT id, inv_prod_id, inv_prod_presentacion_id FROM inv_exi_pres WHERE inv_prod_id='||str_data[4]::integer) LOOP
					exis:=0;
					SELECT count(id) FROM inv_prod_pres_x_prod WHERE producto_id=fila.inv_prod_id AND presentacion_id=fila.inv_prod_presentacion_id INTO exis;
					IF exis<=0 THEN 
						DELETE FROM inv_exi_pres WHERE id=fila.id;
					END IF;
				END LOOP;

				FOR fila IN EXECUTE('select id, inv_prod_id, inv_prod_presentacion_id from env_conf where inv_prod_id='||str_data[4]::integer) LOOP
					exis:=0;
					SELECT count(id) FROM inv_prod_pres_x_prod WHERE producto_id=fila.inv_prod_id AND presentacion_id=fila.inv_prod_presentacion_id INTO exis;
					IF exis<=0 THEN 
						DELETE FROM env_conf WHERE id=fila.id;
						DELETE FROM env_conf_det WHERE env_conf_id=fila.id;
					END IF;
				END LOOP;
			END IF;
			
				
			IF incluye_modulo_produccion=TRUE THEN 
				--para Producto 3=Kit
				IF tipo_producto=3 THEN
					--elimina los prod ingredientes de la tabla inv_kit
					DELETE FROM inv_kit  WHERE producto_kit_id = str_data[4]::integer;
					
					total_filas:= array_length(extra_data,1);
					cont_fila:=1;
					IF extra_data[1] != 'sin datos' THEN
						FOR cont_fila IN 1 .. total_filas LOOP
							SELECT INTO str_filas string_to_array(extra_data[cont_fila],'___');
							--str_filas[1] eliminado
							IF str_filas[1]::integer != 0 THEN--1: no esta eliminado, 0:eliminado
								--ya no se valida nada
								--str_filas[1]	producto_elemento_id
								--str_filas[2] 	cantidad
								INSERT INTO inv_kit(producto_kit_id,producto_elemento_id,cantidad) VALUES (str_data[4]::integer,str_filas[1]::integer,str_filas[2]::double precision);
							END IF;
						END LOOP;
					END IF;
				END IF;	
			ELSE
				
				--Para Producto 1=TERMINADO, 2=INTERMEDIO, 3=KIT, 8=DESARROLLO
				IF tipo_producto=1 OR tipo_producto=2 OR tipo_producto=3 OR tipo_producto=8 THEN 
					--elimina los prod ingredientes de la tabla inv_kit
					DELETE FROM inv_kit  WHERE producto_kit_id=str_data[4]::integer;

					--RAISE EXCEPTION '%','extra_data: '||extra_data;
					
					total_filas:= array_length(extra_data,1);
					cont_fila:=1;
					IF extra_data[1] != 'sin datos' THEN
						FOR cont_fila IN 1 .. total_filas LOOP
							SELECT INTO str_filas string_to_array(extra_data[cont_fila],'___');
							--str_filas[1] eliminado
							IF str_filas[1]::integer<>0 THEN--1: no esta eliminado, 0:eliminado
								--str_filas[1]	producto_elemento_id
								--str_filas[2] 	cantidad
								INSERT INTO inv_kit(producto_kit_id,producto_elemento_id,cantidad) VALUES (str_data[4]::integer,str_filas[1]::integer,str_filas[2]::double precision);
							END IF;
						END LOOP;
					END IF;
				END IF;	
			END IF;
			
			valor_retorno := '1';
		END IF;--termina edit producto
		
		
		
		IF command_selected = 'delete' THEN
			valor_retorno := '1';
			
			IF incluye_modulo_produccion=TRUE THEN
				--aqui buscamos si el producto es formulado
				SELECT count(inv_prod_id) FROM pro_estruc  WHERE inv_prod_id=str_data[4]::integer AND borrado_logico=FALSE INTO exis;
				IF exis > 0 THEN
					valor_retorno := '01';
				ELSE
					exis:=0; --inicializar variable
					--aqui buscamos si el producto forma parte de una formula
					SELECT count(pro_estruc_det.inv_prod_id) FROM pro_estruc_det JOIN pro_estruc ON pro_estruc.id=pro_estruc_det.pro_estruc_id WHERE pro_estruc_det.inv_prod_id=str_data[4]::integer  AND pro_estruc.borrado_logico=FALSE 
					INTO exis;
					
					IF exis > 0 THEN
						valor_retorno := '02';
					END IF;
				END IF;
				
				IF valor_retorno='1' THEN 
					--si el valor retorno sigue igual a 1, entonces tambien buscamos en la tabla de kits
					SELECT count(producto_elemento_id) FROM inv_kit WHERE producto_elemento_id=str_data[4]::integer INTO exis;
					IF exis > 0 THEN
						valor_retorno := '03';
					END IF;
				END IF;
			ELSE
				SELECT count(producto_elemento_id) FROM inv_kit WHERE producto_elemento_id=str_data[4]::integer INTO exis;
				IF exis > 0 THEN
					valor_retorno := '04';
				END IF;
			END IF;
			
			
			IF incluye_modulo_envasado=TRUE THEN 
				--verificamos que el producto no forme parte de una configuracion de envase
				exis:=0;
				SELECT count(env_conf_det.inv_prod_id) FROM env_conf JOIN  env_conf_det ON env_conf_det.env_conf_id=env_conf.id WHERE env_conf_det.inv_prod_id=str_data[4]::integer AND env_conf.borrado_logico=FALSE 
				INTO exis;
				IF exis > 0 THEN
					valor_retorno := '05';
				END IF;
			END IF;


			IF (select sum((inv_exi.exi_inicial - inv_exi.transito - inv_exi.reservado  + inv_exi.entradas_1 - inv_exi.salidas_1 + inv_exi.entradas_2 - inv_exi.salidas_2 + inv_exi.entradas_3 - inv_exi.salidas_3 + inv_exi.entradas_4 - inv_exi.salidas_4 + inv_exi.entradas_5 - inv_exi.salidas_5 + inv_exi.entradas_6 - inv_exi.salidas_6 + inv_exi.entradas_7 - inv_exi.salidas_7 + inv_exi.entradas_8 - inv_exi.salidas_8 + inv_exi.entradas_9 - inv_exi.salidas_9 + inv_exi.entradas_10 - inv_exi.salidas_10 + inv_exi.entradas_11 - inv_exi.salidas_11 + inv_exi.entradas_12 - inv_exi.salidas_12)) AS existencia FROM inv_exi WHERE inv_prod_id=str_data[4]::integer)>0.0001 THEN 
				--No se puede eliminar porque hay existencia en uno o mas almacenes
				valor_retorno := '06';
			END IF;
			
			
			--Si valor retorno es igual a 1, entonces procedemos a eliminar el producto
			IF valor_retorno='1' THEN 
				UPDATE inv_prod SET borrado_logico=true, momento_baja=now(), id_usuario_baja = usuario_id
				WHERE id = str_data[4]::integer;
				
				--elimina los registros de las formulacion del producto
				DELETE FROM inv_kit  WHERE producto_kit_id = str_data[4]::integer;
				
				--elimina los registros de las presentaciones del producto
				DELETE FROM inv_prod_pres_x_prod WHERE producto_id=str_data[4]::integer;
				
				DELETE FROM inv_prod_costos WHERE inv_prod_id=str_data[4]::integer AND ano=EXTRACT(YEAR FROM now());

				DELETE FROM inv_pre WHERE inv_prod_id=str_data[4]::integer AND gral_emp_id=emp_id;

				DELETE FROM inv_exi_pres WHERE inv_prod_id=str_data[4]::integer;
			END IF;
			
			--valor_retorno := '1';
		END IF;
    END IF;
    --termina catalogo de productos
	
        
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
    

    -- Catalogo de nomina de  Percepciones
    IF app_selected = 170 THEN
		IF command_selected = 'new' THEN
			id_tipo_consecutivo:=48;--Folio Catalogo de Percepciones
			
			--aqui entra para tomar el consecutivo del folio de la Percepcionesactual
			UPDATE 	gral_cons SET consecutivo=( SELECT sbt.consecutivo + 1  FROM gral_cons AS sbt WHERE sbt.id=gral_cons.id )
			WHERE gral_emp_id=emp_id AND gral_suc_id=suc_id AND gral_cons_tipo_id=id_tipo_consecutivo  RETURNING prefijo,consecutivo INTO prefijo_consecutivo,nuevo_consecutivo;
			
			--concatenamos el prefijo y el nuevo consecutivo para obtener el nuevo folio 
			nuevo_folio := prefijo_consecutivo || nuevo_consecutivo::character varying;
			
			nuevo_folio:= lpad(nuevo_folio, 3, '0');
			
			--str_data[4]	id
			--str_data clave nuevo_folio
			--str_data[5]	titulo
			--str_data[6]	activo
			--str_data[7]	tipopercepciones
			INSERT INTO nom_percep (clave,titulo,activo,nom_percep_tipo_id,borrado_logico,momento_creacion,gral_usr_id_crea,gral_emp_id,gral_suc_id) 
			VALUES (nuevo_folio,str_data[5],str_data[6]::boolean,str_data[7]::integer,false,now(),usuario_id,emp_id,suc_id);
			valor_retorno := '1';
		END IF;
		
		IF command_selected = 'edit' THEN
			UPDATE nom_percep SET titulo=str_data[5],activo=str_data[6]::boolean,nom_percep_tipo_id=str_data[7]::integer,momento_actualiza=now(),gral_usr_id_actualiza=usuario_id
			WHERE nom_percep.id = str_data[4]::integer;
			valor_retorno := '0';
		END IF;
		
		IF command_selected = 'delete' THEN
			UPDATE nom_percep SET momento_baja=now(),borrado_logico=true WHERE nom_percep.id = str_data[4]::integer;
			valor_retorno := '1';
		END IF;
    END IF;--termina Catalogo Percepciones
	
	
	
    -- Catalogo de nomina de  Deducciones
    IF app_selected = 171 THEN
		IF command_selected = 'new' THEN
			id_tipo_consecutivo:=49;--Folio Catalogo de Deducciones
			
			--aqui entra para tomar el consecutivo del folio  de Deducciones actual
			UPDATE 	gral_cons SET consecutivo=( SELECT sbt.consecutivo + 1  FROM gral_cons AS sbt WHERE sbt.id=gral_cons.id )
			WHERE gral_emp_id=emp_id AND gral_suc_id=suc_id AND gral_cons_tipo_id=id_tipo_consecutivo  RETURNING prefijo,consecutivo INTO prefijo_consecutivo,nuevo_consecutivo;
			
			--concatenamos el prefijo y el nuevo consecutivo para obtener el nuevo folio 
			nuevo_folio := prefijo_consecutivo || nuevo_consecutivo::character varying;
			nuevo_folio:= lpad(nuevo_folio, 3, '0');
			
			--str_data[4]	id
			--str_data clave nuevo_folio
			--str_data[5]	titulo
			--str_data[6]	activo
			--str_data[7]	tipopercepciones
			INSERT INTO nom_deduc (clave,titulo,activo,nom_deduc_tipo_id,borrado_logico,momento_creacion,gral_usr_id_crea,gral_emp_id,gral_suc_id) 
			VALUES (nuevo_folio,str_data[5],str_data[6]::boolean,str_data[7]::integer,false,now(),usuario_id,emp_id,suc_id);
			valor_retorno := '1';
		END IF;
		
		IF command_selected = 'edit' THEN
			UPDATE nom_deduc SET titulo=str_data[5],activo=str_data[6]::boolean,nom_deduc_tipo_id=str_data[7]::integer, momento_actualiza=now(), gral_usr_id_actualiza=usuario_id 
			WHERE nom_deduc.id = str_data[4]::integer;
			valor_retorno := '0';
		END IF;
		
		IF command_selected = 'delete' THEN
			UPDATE nom_deduc SET momento_baja=now(),borrado_logico=true WHERE nom_deduc.id = str_data[4]::integer; 
			valor_retorno := '1';
		END IF;
    END IF;
    --Termina Catalogo Deducciones


	
    -- Catalogo de nomina de Periodicidad de Pago
    IF app_selected = 172 THEN
		IF command_selected = 'new' THEN

			--str_data[4]	id
			--str_data[5]	titulo
			--str_data[6]	no_periodos
			--str_data[7]	activo
			INSERT INTO nom_periodicidad_pago (titulo,no_periodos,activo,borrado_logico,momento_creacion,gral_usr_id_crea,gral_emp_id,gral_suc_id) 
			VALUES (str_data[5],str_data[6]::integer,str_data[7]::boolean,false,now(),usuario_id,emp_id,suc_id);
			valor_retorno := '1';
		END IF;
		
		IF command_selected = 'edit' THEN
			UPDATE nom_periodicidad_pago SET titulo=str_data[5],no_periodos=str_data[6]::integer,activo=str_data[7]::boolean,momento_actualiza=now(), gral_usr_id_actualiza=usuario_id 
			WHERE nom_periodicidad_pago.id = str_data[4]::integer;
			valor_retorno := '0';
		END IF;
		
		IF command_selected = 'delete' THEN
			UPDATE nom_periodicidad_pago SET momento_baja=now(),borrado_logico=true, gral_usr_id_baja=usuario_id  WHERE nom_periodicidad_pago.id = str_data[4]::integer; 
			valor_retorno := '1';
		END IF;
    END IF;
    --Termina Catalogo Periodicidad de Pago




    -- Catalogo de Configuración Periodos
    IF app_selected = 174 THEN
		IF command_selected = 'new' THEN
			--str_data[4]	id
			--str_data clave nuevo_folio
			--str_data[5]	año
			--str_data[6]	tipoperiodicidad
			--str_data[7]	descripcion
			
			INSERT INTO nom_periodos_conf (ano,nom_periodicidad_pago_id,prefijo,borrado_logico,momento_creacion,gral_usr_id_crea,gral_emp_id,gral_suc_id) 
			VALUES (str_data[5]::integer,str_data[6]::integer,str_data[7],false,now(),usuario_id,emp_id,suc_id)
			RETURNING id INTO ultimo_id;
			valor_retorno := '1';
			
			total_filas:= array_length(extra_data,1);
			cont_fila:=1;
			
			IF extra_data[1]<>'sin datos' THEN
				FOR cont_fila IN 1 .. total_filas LOOP
					SELECT INTO str_filas string_to_array(extra_data[cont_fila],'___');
					--str_filas[1]	id_reg 
					--str_filas[2]	id_periodo 
					--str_filas[3]	folio 
					--str_filas[4]	tituloperiodo
					--str_filas[5]	fecha_inicio 
					--str_filas[6]	fecha_final
					
					--crea registro en nom_periodos_conf_det
					INSERT INTO nom_periodos_conf_det(
						nom_periodos_conf_id,--str_data[4]::integer,
						folio,--str_filas[3]	folio 
						titulo,--str_filas[4]	tituloperiodo 
						fecha_ini,--str_filas[5]	fecha_inicio
						fecha_fin--str_filas[6]	fecha_final
						
					 ) VALUES(ultimo_id, str_filas[3]::integer, str_filas[4], str_filas[5]::date,str_filas[6]::date);
					 --RETURNING id INTO ultimo_id;
					 valor_retorno := '1';
				END LOOP;
			END IF;
			
		END IF;
		
		IF command_selected = 'edit' THEN
			UPDATE nom_periodos_conf SET ano=str_data[5]::integer,nom_periodicidad_pago_id=str_data[6]::integer,prefijo=str_data[7],momento_actualiza=now(),gral_usr_id_actualiza=usuario_id 
			WHERE nom_periodos_conf.id = str_data[4]::integer;
			valor_retorno := '0';
			
			total_filas:= array_length(extra_data,1);
			cont_fila:=1;
			
			IF extra_data[1]<>'sin datos' THEN
				FOR cont_fila IN 1 .. total_filas LOOP 
					SELECT INTO str_filas string_to_array(extra_data[cont_fila],'___');
					--str_filas[1]	id_reg 
					--str_filas[2]	id_periodo 
					--str_filas[3]	folio 
					--str_filas[4]	tituloperiodo
					--str_filas[5]	fecha_inicio 
					--str_filas[6]	fecha_final
					
					UPDATE nom_periodos_conf_det SET folio=str_filas[3]::integer,titulo=str_filas[4],fecha_ini=str_filas[5]::date,fecha_fin=str_filas[6]::date
					WHERE nom_periodos_conf_det.id = str_filas[1]::integer;
					valor_retorno := '0';
				END LOOP;
			END IF;
		END IF;
		
		IF command_selected = 'delete' THEN
			UPDATE nom_periodos_conf SET momento_baja=now(),borrado_logico=true 
			WHERE nom_periodos_conf.id = str_data[4]::integer;
			valor_retorno := '1';
		END IF;
    END IF;-- Catalogo de Configuración Periodos
        
    RETURN valor_retorno;
    
END;$$;


ALTER FUNCTION public.gral_adm_catalogos(campos_data text, extra_data text[]) OWNER TO sumar;

--
-- Name: gral_bus_catalogos(text); Type: FUNCTION; Schema: public; Owner: sumar
--

CREATE FUNCTION gral_bus_catalogos(campos_data text) RETURNS SETOF record
    LANGUAGE plpgsql STABLE
    AS $$ 
DECLARE

	str_data text[];
	app_selected integer;
	id_user integer;
	emp_id integer;
	suc_id integer;

	sql_query text;
	fila         record;
	total_items  int:=0;

        cadena_where text;
        f_final character varying;
	
	ano_actual integer;
	mes_actual integer;
	espacio_tiempo_ejecucion timestamp with time zone = now();

BEGIN
	SELECT EXTRACT(YEAR FROM espacio_tiempo_ejecucion) INTO ano_actual;
	SELECT EXTRACT(MONTH FROM espacio_tiempo_ejecucion) INTO mes_actual;
	
	SELECT INTO str_data string_to_array(''||campos_data||'','___');
	
	--aplicativo seleccionado
	app_selected := str_data[1]::integer;
	id_user := str_data[2]::integer;

	--obtiene empresa_id y sucursal_id
	SELECT gral_suc.empresa_id, gral_usr_suc.gral_suc_id FROM gral_usr_suc 	JOIN gral_suc ON gral_suc.id = gral_usr_suc.gral_suc_id
	WHERE gral_usr_suc.gral_usr_id = id_user
	INTO emp_id, suc_id;

	cadena_where:='';

	
	--buscador del Catalogo de Almacenes
	IF app_selected = 1 THEN
		IF str_data[4]::integer != 0 THEN
			cadena_where:= cadena_where ||' AND inv_alm.almacen_tipo_id='||str_data[4];
		END IF;
		sql_query := 'SELECT DISTINCT inv_alm.id 
				FROM inv_alm
				JOIN inv_suc_alm ON inv_suc_alm.almacen_id=inv_alm.id
				JOIN gral_suc ON gral_suc.id=inv_suc_alm.sucursal_id
				WHERE gral_suc.empresa_id='||emp_id||' AND inv_alm.borrado_logico=FALSE AND inv_alm.titulo ILIKE '''||str_data[3]||''' '||cadena_where;
	END IF;	--termina buscador  del Catalogo de almacenes

	--buscador de proveedores
	IF app_selected = 2 THEN
		sql_query := 'select id from cxp_prov where empresa_id='||emp_id||' and sucursal_id='||suc_id||' and borrado_logico=FALSE and razon_social ILIKE '''||str_data[3]||''' AND rfc ilike '''||str_data[4]||''' AND folio ilike '''||str_data[5]||''';';
	END IF;	--termina buscador de proveedores	
	
	--buscador de empleados
        IF app_selected = 4 THEN
                IF str_data[4]::integer=0 THEN
                        sql_query := 'SELECT id FROM gral_empleados WHERE borrado_logico=false AND gral_emp_id = '||emp_id;
                END IF;
                ---por clave empleado
                IF str_data[4]::integer=1 THEN
                        sql_query := 'SELECT id FROM gral_empleados WHERE borrado_logico=false AND gral_emp_id = '|| emp_id ||'  AND  clave ilike '''||str_data[3]||'''';
                END IF;
                --por nombre
                IF str_data[4]::integer=2 THEN
                        sql_query := 'SELECT id FROM gral_empleados WHERE borrado_logico=false AND gral_emp_id = '|| emp_id ||' AND nombre_pila ilike '''||str_data[3]||'''';
                END IF;
                --por curp
                IF str_data[4]::integer=3 THEN
                        sql_query := 'SELECT id FROM gral_empleados WHERE borrado_logico=false AND gral_emp_id = '|| emp_id ||' AND curp ilike '''||str_data[3]||'''';
                END IF;
                --por puesto
                IF str_data[4]::integer=4 THEN
                        sql_query := 'SELECT id FROM gral_empleados WHERE borrado_logico=false AND gral_emp_id = '|| emp_id ||' AND gral_puesto_id '||str_data[3]||'';
                END IF;
        END IF;        --termina buscador de empleados


        --buscador de clientes
	IF app_selected = 5 THEN
		--str_data[3]	nocontrol
		--str_data[4]	razonsoc
		--str_data[5]	rfc
		
		IF str_data[3]<>'' THEN
			cadena_where:= cadena_where ||' and numero_control ilike '''||str_data[3]||'''';
		END IF;
		
		IF str_data[4]<>'%%' THEN
			cadena_where:= cadena_where ||' and razon_social ilike '''||str_data[4]||'''';
		END IF;

		IF str_data[5]<>'%%' THEN
			cadena_where:= cadena_where ||' and rfc ilike '''||str_data[5]||'''';
		END IF;
		
		sql_query := 'select id from cxc_clie where borrado_logico=false and empresa_id='||emp_id||' and borrado_logico=false '||cadena_where;
		
	END IF;	--termina buscador de clientes


	
	--buscador de productos
	IF app_selected = 8 THEN
		--str_data[3]	sku
		--str_data[4]	descripcion
		--str_data[5]	por_tipo
		IF str_data[3] != '%%' THEN
			cadena_where:= cadena_where ||' AND inv_prod.sku ILIKE '''||str_data[3]||'''';
		END IF;
		
		IF str_data[4] != '%%' THEN
			cadena_where:= cadena_where ||' AND  inv_prod.descripcion ILIKE '''||str_data[4]||'''';
		END IF;
		
		IF str_data[5]::integer != 0 THEN
			cadena_where:= cadena_where ||' AND inv_prod.tipo_de_producto_id='||str_data[5]::integer;
		END IF;
		
		sql_query := 'SELECT id FROM inv_prod WHERE empresa_id='||emp_id||' AND borrado_logico=FALSE '||cadena_where;
		
	END IF;	--termina buscador de productos

	
	--buscador de Catalogo Clientes Clasificacion 1
	IF app_selected = 20 THEN
		sql_query := 'SELECT id FROM cxc_clie_clas1 WHERE titulo ILIKE '''||str_data[3]||''';';
	END IF;	--termina Catalogo Clientes Clasificacion 1
	
	--buscador de Catalogo Clientes Clasificacion 2
	IF app_selected = 21 THEN
		sql_query := 'SELECT id FROM cxc_clie_clas2 WHERE titulo ILIKE '''||str_data[3]||''';';
	END IF;	--termina Catalogo Clientes Clasificacion 2
	
	--buscador de Catalogo Clientes Clasificacion 3
	IF app_selected = 22 THEN
		sql_query := 'SELECT id FROM cxc_clie_clas3 WHERE titulo ILIKE '''||str_data[3]||''';';
	END IF;	--termina Catalogo Clientes Clasificacion 3

	--buscador de Catalogo de Zonas de Clientes
        IF app_selected = 23 THEN
                sql_query := 'SELECT id FROM cxc_clie_zonas WHERE titulo ILIKE '''||str_data[3]||''';';
        END IF;        --termina Catalogo de Zonas de Clientes
        
        --buscador de Catalogo de Grupos de Clientes
        IF app_selected = 24 THEN
                sql_query := 'SELECT id FROM cxc_clie_grupos WHERE titulo ILIKE '''||str_data[3]||''';';
        END IF;        --termina Catalogo de Grupos de Clientes


	--buscador de Catalogo Proveedores Clasificacion 1
        IF app_selected = 25 THEN
                sql_query := 'SELECT id FROM cxp_prov_clas1 WHERE titulo ILIKE '''||str_data[3]||''' AND borrado_logico=FALSE AND gral_emp_id= '||emp_id;
        END IF;--termina Catalogo Proveedores Clasificacion 1
        
        --buscador de Catalogo Proveedores Clasificacion 2
        IF app_selected = 26 THEN
                sql_query := 'SELECT id FROM cxp_prov_clas2 WHERE titulo ILIKE '''||str_data[3]||''' AND borrado_logico=FALSE AND gral_emp_id= '||emp_id;
        END IF;--termina Catalogo Proveedores Clasificacion 2
        
        --buscador de Catalogo Proveedores Clasificacion 3
        IF app_selected = 27 THEN
                sql_query := 'SELECT id FROM cxp_prov_clas3 WHERE titulo ILIKE '''||str_data[3]||''' AND borrado_logico=FALSE AND gral_emp_id= '||emp_id;
        END IF;--termina Catalogo Proveedores Clasificacion 3

        --buscador de Catalogo zona de Proveedores
        IF app_selected = 28 THEN
                sql_query := 'SELECT id FROM cxp_prov_zonas WHERE titulo ILIKE '''||str_data[3]||''';';
        END IF;        --termina Catalogo Zona de proveedores

        --buscador de Catalogo grupos de Proveedores
        IF app_selected = 29 THEN
                sql_query := 'SELECT id FROM cxp_prov_grupos WHERE titulo ILIKE '''||str_data[3]||''';';
        END IF;        --termina Catalogo grupos de proveedores

        
	--buscador de Catalogo de tipos de movimientos inventario
        IF app_selected = 35 THEN
                sql_query := 'SELECT id FROM inv_mov_tipos WHERE titulo ILIKE '''||str_data[3]||''' and  descripcion ILIKE '''||str_data[4]||''' and borrado_logico=false;';
        END IF;        --termina Catalogo de tipos de movimientos inventario


	--buscador de Catalogo de inv_secciones
        IF app_selected = 37 THEN
                sql_query := 'SELECT id FROM inv_secciones WHERE titulo ILIKE '''||str_data[3]||''' AND  descripcion ILIKE '''||str_data[4]||''' AND borrado_logico=false AND gral_emp_id='||emp_id;
        END IF;        --termina buscador de Catalogo de inv_secciones
        

	--buscador del catalogo de Marcas
	IF app_selected = 38 THEN
		--str_data[1]	app_selected
		--str_data[2]	id_usuario
		--str_data[3]	descripcion
		sql_query := 'SELECT inv_mar.id
				FROM inv_mar 
				WHERE inv_mar.borrado_logico=false 
				AND titulo ILIKE '''||str_data[3]||''' AND gral_emp_id='||emp_id;
	END IF;	--termina buscador del catalogo   de marcas

	--buscador de Catalogo de inv_prod_lineas
        IF app_selected = 39 THEN
                sql_query := 'SELECT id FROM inv_prod_lineas WHERE titulo ILIKE '''||str_data[3]||''' and  descripcion ILIKE '''||str_data[4]||''' and borrado_logico=false AND gral_emp_id='||emp_id;
        END IF;--termina buscador de Catalogo inv_prod_lineas

	--buscador de Catalogo de familias
        IF app_selected = 43 THEN
                sql_query := 'select id FROM inv_prod_familias WHERE borrado_logico=FALSE AND id=identificador_familia_padre AND titulo ILIKE '''||str_data[3]||''' AND  descripcion ILIKE '''||str_data[4]||''' AND borrado_logico=false AND gral_emp_id='||emp_id;
        END IF;--termina buscador de Catalogo de familias


	--buscador de producto grupos
	IF app_selected =45 THEN
		--str_data[5]	grupo
		--str_data[6]	descripcion
		sql_query := 'SELECT inv_prod_grupos.id
				FROM inv_prod_grupos
				WHERE titulo ILIKE '''||str_data[3]||''' AND borrado_logico=FALSE AND gral_emp_id='||emp_id;
				--RAISE EXCEPTION '%',sql_query;							
	END IF;	--termina buscador  de productos


	--buscador de Catalogo de UNIDADES
        IF app_selected = 49 THEN
		IF str_data[4] != '' THEN
			cadena_where:= cadena_where ||' WHERE  titulo_abr ILIKE '''||str_data[4]||'''';
		END IF;
		
		IF str_data[3] != 'sinvalor' THEN
			cadena_where:= cadena_where ||' and  inv_prod_unidades.decimales='||str_data[3]::integer;
		END IF;
		
		sql_query := 'SELECT id 
				FROM inv_prod_unidades' 
				||cadena_where;
		--RAISE EXCEPTION '%',sql_query;		
        END IF;--termina buscador de Catalogo de UNIDADES


        --buscador de clasificacion stock
	IF app_selected =50 THEN
		--str_data[1]	app_selected
		--str_data[2]	id_usuario
		--str_data[3]	clasificacion
		
		sql_query := 'select inv_stock_clasificaciones.id from inv_stock_clasificaciones 
		     WHERE titulo ILIKE '''||str_data[3]||''' and borrado_logico=false and gral_emp_id='||emp_id||';';
		--RAISE EXCEPTION '%',sql_query;							
	END IF;	--termina buscador  de clasificacion stock


	--buscador de pedidos de clientes
	IF app_selected = 64 THEN
		--str_data[1]	app_selected
		--str_data[2]	id_usuario
		--str_data[3]	folio
		--str_data[4]	cliente
		--str_data[5]	fecha_inicial
		--str_data[6]	fecha_final
		--str_data[7]	codigo
		--str_data[8]	descripcion producto
		--str_data[9]	Agente
		
		IF str_data[3] != '%%' THEN
			cadena_where:= cadena_where ||' AND poc_pedidos.folio ilike  '''||str_data[3]||'''';
		END IF;

		
		IF str_data[4] != '%%' THEN
			cadena_where:= cadena_where ||' AND cxc_clie.razon_social ilike  '''||str_data[4]||'''';
		END IF;
		
		--busqueda por fecha creacion
		IF str_data[5] != '' THEN
			IF str_data[6] = '' THEN
				f_final:=str_data[5];
			ELSE
				f_final:=str_data[6];
			END IF;
			cadena_where:=cadena_where||' AND to_char(poc_pedidos.momento_creacion, ''yyyymmdd'')::integer between (to_char('''||str_data[5]||'''::timestamp with time zone,''yyyymmdd'')::integer) and (to_char('''||f_final||'''::timestamp with time zone,''yyyymmdd'')::integer)';
		END IF;

		IF str_data[7] != '%%' THEN
			cadena_where:= cadena_where ||' AND inv_prod.sku ilike  '''||str_data[7]||'''';
		END IF;
		
		IF str_data[8] != '%%' THEN
			cadena_where:= cadena_where ||' AND inv_prod.descripcion ilike  '''||str_data[8]||'''';
		END IF;

		IF str_data[9]::integer != 0 THEN
			cadena_where:= cadena_where ||' AND poc_pedidos.cxc_agen_id='||str_data[9];
		END IF;
		sql_query := 'SELECT DISTINCT poc_pedidos.id 
				FROM poc_pedidos 
				LEFT JOIN poc_pedidos_detalle ON poc_pedidos_detalle.poc_pedido_id = poc_pedidos.id  
				LEFT JOIN inv_prod ON inv_prod.id = poc_pedidos_detalle.inv_prod_id  
				JOIN erp_proceso ON erp_proceso.id = poc_pedidos.proceso_id
				LEFT JOIN cxc_clie ON cxc_clie.id = poc_pedidos.cxc_clie_id  
				WHERE erp_proceso.empresa_id='||emp_id||' AND  erp_proceso.sucursal_id='||suc_id||' AND poc_pedidos.borrado_logico=FALSE  '||cadena_where;
		--RAISE EXCEPTION '%' ,sql_query;
	END IF;	--termina buscador de pedidos de clientes

        
	--buscador del catalogo de PUESTOS
	IF app_selected = 75 THEN
		--str_data[1]	app_selected
		--str_data[2]	id_usuario
		--str_data[3]	TITULO
		IF str_data[3] !='%%' THEN
			cadena_where='and titulo ilike '''||str_data[3]||'''';
		END IF;
		
		sql_query := 'select id from gral_puestos where gral_emp_id='||emp_id||' and borrado_logico=false '||cadena_where;
	END IF;	--termina buscador del catalogo de puestos


	--buscador del catalogo de escolaridades
	IF app_selected = 77 THEN
		--str_data[1]	app_selected
		--str_data[2]	id_usuario
		--str_data[3]	TITULO
		IF str_data[3] !='%%' THEN
			cadena_where='AND gral_escolaridads.titulo ilike '''||str_data[3]||'''';
		END IF;
		
		sql_query := 'SELECT id
			      FROM gral_escolaridads 
			      WHERE gral_escolaridads.gral_emp_id='||emp_id||' AND gral_escolaridads.borrado_logico=false '||cadena_where;
	END IF;	--termina buscador del catalogo escolaridad


	--buscador del catalogo de religiones
	IF app_selected = 78 THEN
		--str_data[1]	app_selected
		--str_data[2]	id_usuario
		--str_data[3]	TITULO
		IF str_data[3] !='%%' THEN
			cadena_where='AND gral_religions.titulo ilike '''||str_data[3]||'''';
		END IF;
		
		sql_query := 'SELECT id FROM gral_religions WHERE gral_religions.gral_emp_id='||emp_id||' AND gral_religions.borrado_logico=false '||cadena_where;
	END IF;	--termina buscador del catalogo religiones


	--buscador del catalogo de tipo de sangre
	IF app_selected = 79 THEN
		--str_data[1]	app_selected
		--str_data[2]	id_usuario
		--str_data[3]	TITULO
		IF str_data[3] !='%%' THEN
			cadena_where='AND gral_sangretipos.titulo ilike '''||str_data[3]||'''';
		END IF;
		
		sql_query := 'SELECT id
			      FROM gral_sangretipos 
			      WHERE gral_sangretipos.gral_emp_id='||emp_id||' AND gral_sangretipos.borrado_logico=false '||cadena_where;
	END IF;	--termina buscador del catalogo tipo de sangre


	--buscador del catalogo de departamentos
	IF app_selected = 82 THEN
		--str_data[1]	app_selected
		--str_data[2]	id_usuario
		--str_data[3]	TITULO
		--str_data[3]	costo
		IF str_data[3] !='%%' THEN
			cadena_where='AND gral_deptos.titulo ilike '''||str_data[3]||'''';
		END IF;
		IF str_data[4] !='' THEN
			cadena_where=cadena_where||'AND gral_deptos.costo_prorrateo = '''||str_data[4]||'''';
		END IF;    
		sql_query := 'SELECT id
			      FROM gral_deptos 
			      WHERE gral_deptos.gral_emp_id='||emp_id||' AND gral_deptos.vigente=true AND gral_deptos.borrado_logico=false '||cadena_where;
				--RAISE EXCEPTION '%' ,sql_query;
	END IF;	--termina buscador del catalogo departamentos


	--buscador del catalogo de DIAS NO LABORABLES
	IF app_selected = 84 THEN
			--str_data[1]        app_selected
			--str_data[2]        id_usuario
			--str_data[3]        fecha_no_laborable date
			--str_data[4]        descripcion string	
			--str_data[5]        gral_puesto_id (puesto) integer   
		IF str_data[3] != '' THEN
			cadena_where=' AND gral_dias_no_laborables.fecha_no_laborable = '''||str_data[3]||'''::date';
		END IF;		

		IF str_data[4] != '' THEN
			cadena_where = cadena_where||' AND gral_dias_no_laborables.descripcion ILIKE '''||str_data[4]||'''';
		END IF;
		
		sql_query := 'SELECT id
			      FROM gral_dias_no_laborables 
			      WHERE gral_dias_no_laborables.gral_emp_id='||emp_id||' AND gral_dias_no_laborables.borrado_logico=false '||cadena_where;
	END IF;	--termina buscador del catalogo dias no laborables
		

	--buscador del catalogo de categorias
	IF app_selected = 85 THEN
			--str_data[1]        app_selected
			--str_data[2]        id_usuario
			
			--str_data[3]        titulo(categ) char
			--str_data[4]        sueldo_por_hora double	
			--str_data[5]        sueldo_por_horas_ext double
			--str_data[6]        gral_puesto_id (puesto) integer
		IF str_data[3] !='' THEN
			cadena_where=' AND gral_categ.titulo ilike '''||str_data[3]||'''';
		END IF;
		

		IF str_data[4] != '' THEN
			cadena_where = cadena_where||' AND gral_categ.sueldo_por_hora = '||str_data[4]::double precision;
		END IF;
		
		
		IF str_data[5] != '' THEN
			cadena_where = cadena_where||' AND gral_categ.sueldo_por_horas_ext = '||str_data[5]::double precision;
		END IF;
		
		
		IF str_data[6] != '0' THEN
			cadena_where = cadena_where||' AND gral_categ.gral_puesto_id = '||str_data[6]::integer;
		END IF;
		
		sql_query := 'SELECT id
			      FROM gral_categ 
			      WHERE gral_categ.gral_emp_id='||emp_id||' AND gral_categ.borrado_logico=false '||cadena_where;
	END IF;	--termina buscador del catalogo categorias


	--buscador del catalogo de TURNOS
	IF app_selected = 92 THEN
			--str_data[1]        app_selected
			--str_data[2]        id_usuario
			
			--str_data[3]        titulo(categ) char
			--str_data[4]        sueldo_por_hora double	
			--str_data[5]        sueldo_por_horas_ext double
			--str_data[6]        gral_puesto_id (puesto) integer
		IF str_data[3] !='' THEN
			cadena_where=' AND gral_deptos_turnos.turno = '''||str_data[3]||'''';
		END IF;
		

		IF str_data[4] != '' THEN
			cadena_where = cadena_where||' AND gral_deptos_turnos.hora_ini = '''||str_data[4]||'''::time with time zone';
		END IF;
		
		
		IF str_data[5] != '' THEN
			cadena_where = cadena_where||' AND gral_deptos_turnos.hora_fin = '''||str_data[5]||'''::time with time zone';
		END IF;
		
		
		IF str_data[6] != '0' THEN
			cadena_where = cadena_where||' AND gral_deptos_turnos.gral_deptos_id = '||str_data[6]::integer;
		END IF;
		
			sql_query := 'SELECT id
				      FROM gral_deptos_turnos 
				      WHERE gral_deptos_turnos.gral_emp_id='||emp_id||' AND gral_deptos_turnos.borrado_logico=false '||cadena_where;
	END IF;	--termina buscador del catalogo TURNOS


	--buscador de Direcciones Fiscales de clientes
	IF app_selected = 118 THEN
		--str_data[3]	nocontrol
		--str_data[4]	razonsoc
		--str_data[5]	rfc
		
		IF str_data[3]!='' THEN
			cadena_where:= cadena_where ||' AND cxc_clie.numero_control ILIKE '''||str_data[3]||'''';
		END IF;
		
		IF str_data[4]!='%%' THEN
			cadena_where:= cadena_where ||' AND cxc_clie.razon_social ILIKE '''||str_data[4]||'''';
		END IF;

		IF str_data[5]!='%%' THEN
			cadena_where:= cadena_where ||' AND cxc_clie.rfc ILIKE '''||str_data[5]||'''';
		END IF;

		sql_query := 'SELECT cxc_clie_df.id  
		FROM cxc_clie_df 
		JOIN cxc_clie ON cxc_clie.id = cxc_clie_df.cxc_clie_id 
		WHERE cxc_clie_df.borrado_logico=false 
		AND cxc_clie.empresa_id = '|| emp_id ||' '||cadena_where;
	END IF;	--termina buscador de clientes


	--Buscador de Aplicativo Actualizador de Contraseña de Usuario
	IF app_selected = 155 THEN
		sql_query := 'select gral_usr.id from gral_usr left join gral_empleados on gral_empleados.id=gral_usr.gral_empleados_id where gral_usr.id='||id_user||';';
	END IF;	--Termina Buscador de Aplicativo Actualizador de Contraseña de Usuario

	
	--Buscador del catalogo de Percepcines
	IF app_selected = 170 THEN
		--str_data[1]	app_selected
		--str_data[2]	id_usuario
		--str_data[3]	TITULO
		IF str_data[3] !='%%' THEN
			cadena_where='AND titulo ilike '''||str_data[3]||'''';
		END IF;
		
		sql_query := 'SELECT id FROM nom_percep WHERE gral_emp_id='||emp_id||' AND borrado_logico=false '||cadena_where;
	END IF;	--termina buscador del catalogo de Percepciones

	
	--Buscador del catalogo de Deducciones
	IF app_selected = 171 THEN
		--str_data[1]	app_selected
		--str_data[2]	id_usuario
		--str_data[3]	TITULO
		IF str_data[3]<>'%%' THEN
			cadena_where='AND titulo ilike '''||str_data[3]||'''';
		END IF;
		
		sql_query := 'SELECT id FROM nom_deduc WHERE gral_emp_id='||emp_id||' AND borrado_logico=false '||cadena_where;
	END IF;
	--Termina buscador del catalogo de Deducciones


	--Buscador del catalogo de Periodicidad de Pago
	IF app_selected = 172 THEN
		--str_data[1]	app_selected
		--str_data[2]	id_usuario
		--str_data[3]	titulo
		IF str_data[3] !='%%' THEN
			cadena_where='AND titulo ilike '''||str_data[3]||'''';
		END IF;
		
		sql_query := 'SELECT id FROM nom_periodicidad_pago WHERE gral_emp_id='||emp_id||' AND borrado_logico=false '||cadena_where;
	END IF;
	--Termina buscador del catalogo de Periodicidad de Pago


	--Buscador para el Aplicativo de Facturacion de Nominas
	IF app_selected = 173 THEN
		--str_data[1]	app_selected
		--str_data[2]	id_usuario
		--str_data[3]	no_periodo
		--str_data[4]	titulo_periodo
		--str_data[5]	tipo_periodo
		--str_data[6]	fecha_inicial
		--str_data[7]	fecha_final
		
		IF str_data[3]<>'%%' THEN
			cadena_where=' AND (nom_periodos_conf.prefijo||nom_periodos_conf_det.folio) ilike '''||str_data[3]||'''';
		END IF;

		IF str_data[4]<>'%%' THEN
			cadena_where=' AND nom_periodos_conf_det.titulo ilike '''||str_data[4]||'''';
		END IF;

		IF str_data[5]::integer<>0 THEN
			cadena_where=' AND fac_nomina.nom_periodicidad_pago_id='||str_data[5]||' ';
		END IF;
		
		--Busqueda por Fecha de Pago
		IF str_data[6]<>'' THEN
			IF str_data[7]='' THEN
				f_final:=str_data[6];
			ELSE
				f_final:=str_data[7];
			END IF;
			cadena_where:=cadena_where||' AND to_char(fac_nomina.fecha_pago::timestamp with time zone, ''yyyymmdd'')::integer between (to_char('''||str_data[6]||'''::timestamp with time zone,''yyyymmdd'')::integer) and (to_char('''||f_final||'''::timestamp with time zone,''yyyymmdd'')::integer)';
		END IF;
		
		sql_query := '
		SELECT fac_nomina.id FROM fac_nomina 
		JOIN nom_periodos_conf_det ON nom_periodos_conf_det.id=fac_nomina.nom_periodicidad_pago_id 
		JOIN nom_periodos_conf ON nom_periodos_conf.id=nom_periodos_conf_det.nom_periodos_conf_id
		WHERE fac_nomina.gral_emp_id='||emp_id||' '||cadena_where;
	END IF;
	--Termina buscador para el Aplicativo de Facturacion de Nominas
	
	
	--Buscador del catalogo de Configuracion de  Periodicidad de Pago
	IF app_selected = 174 THEN
		--str_data[1]	app_selected
		--str_data[2]	id_usuario
		--str_data[3]	anio
		--str_data[4]	titulo

		IF str_data[3]::integer != 0 THEN
			cadena_where:= cadena_where ||' AND nom_periodos_conf.ano='||str_data[3];
		END IF;
		
		IF str_data[4] !='%%' THEN
			cadena_where:= cadena_where ||' AND nom_periodicidad_pago.titulo ilike  '''||str_data[4]||'''';
		END IF;
		
		sql_query := 'SELECT nom_periodos_conf.id FROM nom_periodos_conf 
		JOIN nom_periodicidad_pago on nom_periodicidad_pago.id=nom_periodos_conf.nom_periodicidad_pago_id
		WHERE nom_periodos_conf.gral_emp_id = '|| emp_id ||' AND nom_periodos_conf.borrado_logico=FALSE '||cadena_where;
		
	
	END IF;
	--Termina buscador para el Aplicativo de Configuracion de  Periodicidad de Pago
		


	--RAISE EXCEPTION '%',sql_query;
	
	FOR fila IN EXECUTE (sql_query) LOOP
		total_items := 1 + total_items;
		RETURN NEXT fila;
	END LOOP;
	
	IF total_items = 0 THEN
		fila.id:= -1; -- return current row of SELECT
		RETURN NEXT fila;
	END IF;
	
END; 
$$;


ALTER FUNCTION public.gral_bus_catalogos(campos_data text) OWNER TO sumar;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: gral_rol; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: gral_usr; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: gral_usr_rol; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: ctb_may_clases; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE ctb_may_clases (
    id integer NOT NULL,
    titulo character varying NOT NULL
);


ALTER TABLE ctb_may_clases OWNER TO sumar;

--
-- Name: ctb_may_clases_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE ctb_may_clases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ctb_may_clases_id_seq OWNER TO sumar;

--
-- Name: ctb_may_clases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE ctb_may_clases_id_seq OWNED BY ctb_may_clases.id;


--
-- Name: gral_empleados; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: cxc_agen; Type: VIEW; Schema: public; Owner: sumar
--

CREATE VIEW cxc_agen AS
 SELECT gral_empleados.id,
    (((((gral_empleados.nombre_pila)::text || ' '::text) || (gral_empleados.apellido_paterno)::text) || ' '::text) || (gral_empleados.apellido_materno)::text) AS nombre,
    gral_empleados.comision_agen AS comision,
    gral_empleados.region_id_agen AS gral_reg_id,
        CASE
            WHEN (gral_usr.id IS NULL) THEN 0
            ELSE gral_usr.id
        END AS gral_usr_id,
    gral_empleados.borrado_logico,
    gral_empleados.momento_actualizacion,
    gral_empleados.momento_creacion,
    gral_empleados.momento_baja,
    gral_empleados.gral_usr_id_creacion,
    gral_empleados.gral_usr_id_actualizacion,
    gral_empleados.gral_usr_id_baja,
    gral_empleados.comision2_agen AS comision2,
    gral_empleados.comision3_agen AS comision3,
    gral_empleados.comision4_agen AS comision4,
    gral_empleados.dias_tope_comision,
    gral_empleados.dias_tope_comision2,
    gral_empleados.dias_tope_comision3,
    gral_empleados.monto_tope_comision,
    gral_empleados.monto_tope_comision2,
    gral_empleados.monto_tope_comision3
   FROM (gral_empleados
     LEFT JOIN gral_usr ON ((gral_usr.gral_empleados_id = gral_empleados.id)))
  WHERE ((gral_empleados.gral_puesto_id = 2) AND (gral_empleados.borrado_logico = false));


ALTER TABLE cxc_agen OWNER TO sumar;

--
-- Name: cxc_clie; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxc_clie (
    id integer NOT NULL,
    numero_control character varying,
    rfc character varying DEFAULT ''::character varying NOT NULL,
    curp character varying DEFAULT ''::character varying,
    razon_social character varying DEFAULT ''::character varying NOT NULL,
    clave_comercial character varying DEFAULT ''::character varying,
    calle character varying DEFAULT ''::character varying NOT NULL,
    numero character varying DEFAULT ''::character varying NOT NULL,
    entre_calles character varying DEFAULT ''::character varying NOT NULL,
    numero_exterior character varying DEFAULT ''::character varying,
    colonia character varying DEFAULT ''::character varying NOT NULL,
    cp character varying DEFAULT ''::character varying NOT NULL,
    pais_id integer DEFAULT 0,
    estado_id integer DEFAULT 0,
    municipio_id integer DEFAULT 0,
    localidad_alternativa character varying DEFAULT ''::character varying,
    telefono1 character varying DEFAULT ''::character varying,
    extension1 character varying DEFAULT ''::character varying,
    fax character varying DEFAULT ''::character varying,
    telefono2 character varying DEFAULT ''::character varying,
    extension2 character varying DEFAULT ''::character varying,
    email character varying DEFAULT ''::character varying,
    cxc_agen_id integer DEFAULT 0,
    contacto character varying DEFAULT ''::character varying,
    zona_id integer DEFAULT 0,
    cxc_clie_grupo_id integer DEFAULT 0,
    clienttipo_id integer DEFAULT 0 NOT NULL,
    clasif_1 integer DEFAULT 0,
    clasif_2 integer DEFAULT 0,
    clasif_3 integer DEFAULT 0,
    moneda integer DEFAULT 0,
    filial boolean DEFAULT false,
    estatus boolean DEFAULT true,
    gral_imp_id integer DEFAULT 0,
    limite_credito double precision DEFAULT 0,
    dias_credito_id integer DEFAULT 0,
    credito_suspendido boolean DEFAULT false,
    credito_a_partir integer DEFAULT 0,
    cxp_prov_tipo_embarque_id integer DEFAULT 0,
    dias_caducidad_cotizacion integer DEFAULT 0,
    condiciones text DEFAULT ''::text,
    observaciones text DEFAULT ''::text,
    contacto_compras_nombre character varying DEFAULT ''::character varying,
    contacto_compras_puesto character varying DEFAULT ''::character varying,
    contacto_compras_calle character varying DEFAULT ''::character varying,
    contacto_compras_numero character varying DEFAULT ''::character varying,
    contacto_compras_colonia character varying DEFAULT ''::character varying,
    contacto_compras_cp character varying DEFAULT ''::character varying,
    contacto_compras_entre_calles character varying DEFAULT ''::character varying,
    contacto_compras_pais_id integer DEFAULT 0,
    contacto_compras_estado_id integer DEFAULT 0,
    contacto_compras_municipio_id integer DEFAULT 0,
    contacto_compras_telefono1 character varying DEFAULT ''::character varying,
    contacto_compras_extension1 character varying DEFAULT ''::character varying,
    contacto_compras_fax character varying DEFAULT ''::character varying,
    contacto_compras_telefono2 character varying DEFAULT ''::character varying,
    contacto_compras_extension2 character varying DEFAULT ''::character varying,
    contacto_compras_email character varying DEFAULT ''::character varying,
    contacto_pagos_nombre character varying DEFAULT ''::character varying,
    contacto_pagos_puesto character varying DEFAULT ''::character varying,
    contacto_pagos_calle character varying DEFAULT ''::character varying,
    contacto_pagos_numero character varying DEFAULT ''::character varying,
    contacto_pagos_colonia character varying DEFAULT ''::character varying,
    contacto_pagos_cp character varying DEFAULT ''::character varying,
    contacto_pagos_entre_calles character varying DEFAULT ''::character varying,
    contacto_pagos_pais_id integer DEFAULT 0,
    contacto_pagos_estado_id integer DEFAULT 0,
    contacto_pagos_municipio_id integer DEFAULT 0,
    contacto_pagos_telefono1 character varying DEFAULT ''::character varying,
    contacto_pagos_extension1 character varying DEFAULT ''::character varying,
    contacto_pagos_fax character varying DEFAULT ''::character varying,
    contacto_pagos_telefono2 character varying DEFAULT ''::character varying,
    contacto_pagos_extension2 character varying DEFAULT ''::character varying,
    contacto_pagos_email character varying DEFAULT ''::character varying,
    empresa_id integer DEFAULT 0,
    sucursal_id integer DEFAULT 0,
    borrado_logico boolean DEFAULT false NOT NULL,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    id_usuario_creacion integer DEFAULT 0,
    id_usuario_actualizacion integer DEFAULT 0,
    id_usuario_baja integer DEFAULT 0,
    id_aux integer,
    empresa_immex boolean DEFAULT false,
    tasa_ret_immex double precision DEFAULT 0,
    dia_revision smallint DEFAULT 0,
    dia_pago smallint DEFAULT 0,
    cta_pago_mn character varying DEFAULT ''::character varying,
    cta_pago_usd character varying DEFAULT ''::character varying,
    ctb_cta_id_activo integer DEFAULT 0,
    ctb_cta_id_ingreso integer DEFAULT 0,
    ctb_cta_id_ietu integer DEFAULT 0,
    ctb_cta_id_comple integer DEFAULT 0,
    ctb_cta_id_activo_comple integer DEFAULT 0,
    lista_precio integer DEFAULT 0,
    fac_metodos_pago_id integer DEFAULT 0,
    cxc_clie_tipo_adenda_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE cxc_clie OWNER TO sumar;

--
-- Name: COLUMN cxc_clie.ctb_cta_id_activo; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN cxc_clie.ctb_cta_id_activo IS 'id de la Cuenta Contable para Activo';


--
-- Name: COLUMN cxc_clie.ctb_cta_id_ingreso; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN cxc_clie.ctb_cta_id_ingreso IS 'id de la Cuenta Contable para Ingresos';


--
-- Name: COLUMN cxc_clie.ctb_cta_id_ietu; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN cxc_clie.ctb_cta_id_ietu IS 'id de la Cuenta Contable para IETU';


--
-- Name: COLUMN cxc_clie.ctb_cta_id_comple; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN cxc_clie.ctb_cta_id_comple IS 'id de la Cuenta Contable para Complementeria';


--
-- Name: COLUMN cxc_clie.ctb_cta_id_activo_comple; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN cxc_clie.ctb_cta_id_activo_comple IS 'id de la Cuenta Contable para Activo Complementaria';


--
-- Name: cxc_clie_clas1; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxc_clie_clas1 (
    id integer NOT NULL,
    titulo character varying NOT NULL
);


ALTER TABLE cxc_clie_clas1 OWNER TO sumar;

--
-- Name: cxc_clie_clas1_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxc_clie_clas1_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxc_clie_clas1_id_seq OWNER TO sumar;

--
-- Name: cxc_clie_clas1_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxc_clie_clas1_id_seq OWNED BY cxc_clie_clas1.id;


--
-- Name: cxc_clie_clas2; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxc_clie_clas2 (
    id integer NOT NULL,
    titulo character varying NOT NULL
);


ALTER TABLE cxc_clie_clas2 OWNER TO sumar;

--
-- Name: cxc_clie_clas2_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxc_clie_clas2_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxc_clie_clas2_id_seq OWNER TO sumar;

--
-- Name: cxc_clie_clas2_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxc_clie_clas2_id_seq OWNED BY cxc_clie_clas2.id;


--
-- Name: cxc_clie_clas3; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxc_clie_clas3 (
    id integer NOT NULL,
    titulo character varying NOT NULL
);


ALTER TABLE cxc_clie_clas3 OWNER TO sumar;

--
-- Name: cxc_clie_clas3_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxc_clie_clas3_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxc_clie_clas3_id_seq OWNER TO sumar;

--
-- Name: cxc_clie_clas3_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxc_clie_clas3_id_seq OWNED BY cxc_clie_clas3.id;


--
-- Name: cxc_clie_clases; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxc_clie_clases (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    borrado_logico boolean
);


ALTER TABLE cxc_clie_clases OWNER TO sumar;

--
-- Name: TABLE cxc_clie_clases; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON TABLE cxc_clie_clases IS 'Tabla que alberga todos los distintos tipos que existen de clientes';


--
-- Name: COLUMN cxc_clie_clases.id; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN cxc_clie_clases.id IS 'Indicador secuencial que identifica la fila, este  es autoincremental';


--
-- Name: cxc_clie_clases_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxc_clie_clases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxc_clie_clases_id_seq OWNER TO sumar;

--
-- Name: cxc_clie_clases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxc_clie_clases_id_seq OWNED BY cxc_clie_clases.id;


--
-- Name: cxc_clie_creapar; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxc_clie_creapar (
    id integer NOT NULL,
    titulo character varying NOT NULL
);


ALTER TABLE cxc_clie_creapar OWNER TO sumar;

--
-- Name: TABLE cxc_clie_creapar; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON TABLE cxc_clie_creapar IS 'Alberga los posibles puntos de arranque de un credito (apartir de cuando se otorga un credito)';


--
-- Name: cxc_clie_creapar_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxc_clie_creapar_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxc_clie_creapar_id_seq OWNER TO sumar;

--
-- Name: cxc_clie_creapar_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxc_clie_creapar_id_seq OWNED BY cxc_clie_creapar.id;


--
-- Name: cxc_clie_credias; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxc_clie_credias (
    id integer NOT NULL,
    descripcion text,
    dias integer,
    borrado_logico boolean DEFAULT false,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    tipo_cambio double precision DEFAULT 0,
    id_usuario_creacion integer DEFAULT 0,
    id_usuario_actualizacion integer DEFAULT 0,
    id_usuario_baja integer DEFAULT 0,
    sucursal_id integer DEFAULT 0
);


ALTER TABLE cxc_clie_credias OWNER TO sumar;

--
-- Name: TABLE cxc_clie_credias; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON TABLE cxc_clie_credias IS 'Alberga todos los posibles dias credito que se le pueden dar a un cliente';


--
-- Name: cxc_clie_credias_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxc_clie_credias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxc_clie_credias_id_seq OWNER TO sumar;

--
-- Name: cxc_clie_credias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxc_clie_credias_id_seq OWNED BY cxc_clie_credias.id;


--
-- Name: cxc_clie_descto; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxc_clie_descto (
    id integer NOT NULL,
    cxc_clie_id integer NOT NULL,
    tipo integer DEFAULT 0 NOT NULL,
    valor double precision DEFAULT 0 NOT NULL,
    CONSTRAINT chk_cxc_clie_tipo CHECK ((tipo = 1)),
    CONSTRAINT chk_cxc_clie_valor CHECK ((valor >= (0)::double precision))
);


ALTER TABLE cxc_clie_descto OWNER TO sumar;

--
-- Name: cxc_clie_descto_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxc_clie_descto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxc_clie_descto_id_seq OWNER TO sumar;

--
-- Name: cxc_clie_descto_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxc_clie_descto_id_seq OWNED BY cxc_clie_descto.id;


--
-- Name: cxc_clie_df; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxc_clie_df (
    id integer NOT NULL,
    cxc_clie_id integer NOT NULL,
    calle character varying DEFAULT ''::character varying NOT NULL,
    numero_interior character varying DEFAULT ''::character varying NOT NULL,
    numero_exterior character varying DEFAULT ''::character varying NOT NULL,
    entre_calles character varying DEFAULT ''::character varying NOT NULL,
    colonia character varying DEFAULT ''::character varying NOT NULL,
    cp character varying DEFAULT ''::character varying NOT NULL,
    gral_pais_id integer DEFAULT 0,
    gral_edo_id integer DEFAULT 0,
    gral_mun_id integer DEFAULT 0,
    telefono1 character varying DEFAULT ''::character varying,
    extension1 character varying DEFAULT ''::character varying,
    telefono2 character varying DEFAULT ''::character varying,
    extension2 character varying DEFAULT ''::character varying,
    fax character varying DEFAULT ''::character varying,
    email character varying DEFAULT ''::character varying,
    borrado_logico boolean DEFAULT false,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gra_usr_id_creacion integer DEFAULT 0,
    gra_usr_id_actualizacion integer DEFAULT 0,
    gra_usr_id_baja integer DEFAULT 0,
    contacto character varying DEFAULT ''::character varying
);


ALTER TABLE cxc_clie_df OWNER TO sumar;

--
-- Name: TABLE cxc_clie_df; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON TABLE cxc_clie_df IS 'Tabla de direcciones fiscales de clientes. En ésta tabla existe un registro con el ID=1. Éste registro es para  utilizarla como llave foranea en las tablas poc_pedidos, erp_prefacturas, fac_docs y fac_rems en el caso de que la dirección de Facturación sea la DEFAULT, es decir, la dirección que se encuentra en la tabla de Clientes(cxc_clie)';


--
-- Name: cxc_clie_df_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxc_clie_df_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxc_clie_df_id_seq OWNER TO sumar;

--
-- Name: cxc_clie_df_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxc_clie_df_id_seq OWNED BY cxc_clie_df.id;


--
-- Name: cxc_clie_grupos; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxc_clie_grupos (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    borrado_logico boolean
);


ALTER TABLE cxc_clie_grupos OWNER TO sumar;

--
-- Name: cxc_clie_grupos_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxc_clie_grupos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxc_clie_grupos_id_seq OWNER TO sumar;

--
-- Name: cxc_clie_grupos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxc_clie_grupos_id_seq OWNED BY cxc_clie_grupos.id;


--
-- Name: cxc_clie_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxc_clie_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxc_clie_id_seq OWNER TO sumar;

--
-- Name: cxc_clie_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxc_clie_id_seq OWNED BY cxc_clie.id;


--
-- Name: cxc_clie_tipos_embarque; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxc_clie_tipos_embarque (
    id integer NOT NULL,
    titulo character varying NOT NULL
);


ALTER TABLE cxc_clie_tipos_embarque OWNER TO sumar;

--
-- Name: cxc_clie_tipos_embarque_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxc_clie_tipos_embarque_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxc_clie_tipos_embarque_id_seq OWNER TO sumar;

--
-- Name: cxc_clie_tipos_embarque_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxc_clie_tipos_embarque_id_seq OWNED BY cxc_clie_tipos_embarque.id;


--
-- Name: cxc_clie_zonas; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxc_clie_zonas (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    borrado_logico boolean
);


ALTER TABLE cxc_clie_zonas OWNER TO sumar;

--
-- Name: cxc_clie_zonas_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxc_clie_zonas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxc_clie_zonas_id_seq OWNER TO sumar;

--
-- Name: cxc_clie_zonas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxc_clie_zonas_id_seq OWNED BY cxc_clie_zonas.id;


--
-- Name: cxp_prov; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxp_prov (
    id integer NOT NULL,
    folio character varying,
    rfc character varying,
    curp character varying DEFAULT ''::character varying,
    razon_social character varying DEFAULT ''::character varying,
    clave_comercial character varying DEFAULT ''::character varying NOT NULL,
    calle character varying DEFAULT ''::character varying,
    numero character varying DEFAULT ''::character varying,
    colonia character varying DEFAULT ''::character varying,
    cp character varying DEFAULT ''::character varying,
    entre_calles character varying DEFAULT ''::character varying,
    pais_id integer DEFAULT 0,
    estado_id integer DEFAULT 0,
    municipio_id integer DEFAULT 0,
    localidad_alternativa character varying DEFAULT ''::character varying,
    telefono1 character varying DEFAULT ''::character varying,
    extension1 character varying DEFAULT ''::character varying,
    fax character varying DEFAULT ''::character varying,
    telefono2 character varying DEFAULT ''::character varying,
    extension2 character varying DEFAULT ''::character varying,
    correo_electronico character varying DEFAULT ''::character varying,
    web_site character varying DEFAULT ''::character varying,
    impuesto integer DEFAULT 0,
    cxp_prov_zona_id integer DEFAULT 0,
    grupo_id integer DEFAULT 0,
    proveedortipo_id integer DEFAULT 0,
    clasif_1 integer DEFAULT 0,
    clasif_2 integer DEFAULT 0,
    clasif_3 integer DEFAULT 0,
    moneda_id integer DEFAULT 0,
    tiempo_entrega_id integer DEFAULT 0,
    estatus boolean DEFAULT true,
    limite_credito double precision DEFAULT 0,
    dias_credito_id integer DEFAULT 0,
    descuento double precision DEFAULT 0,
    credito_a_partir integer DEFAULT 0,
    cxp_prov_tipo_embarque_id integer DEFAULT 0,
    flete_pagado boolean DEFAULT false,
    condiciones text DEFAULT ''::text,
    observaciones text DEFAULT ''::text,
    vent_contacto character varying DEFAULT ''::character varying,
    vent_puesto character varying DEFAULT ''::character varying,
    vent_calle character varying DEFAULT ''::character varying,
    vent_numero character varying DEFAULT ''::character varying,
    vent_colonia character varying DEFAULT ''::character varying,
    vent_cp character varying DEFAULT ''::character varying,
    vent_entre_calles character varying DEFAULT ''::character varying,
    vent_pais_id integer DEFAULT 0,
    vent_estado_id integer DEFAULT 0,
    vent_municipio_id integer DEFAULT 0,
    vent_telefono1 character varying DEFAULT ''::character varying,
    vent_extension1 character varying DEFAULT ''::character varying,
    vent_fax character varying DEFAULT ''::character varying,
    vent_telefono2 character varying DEFAULT ''::character varying,
    vent_extension2 character varying DEFAULT ''::character varying,
    vent_email character varying DEFAULT ''::character varying,
    cob_contacto character varying DEFAULT ''::character varying,
    cob_puesto character varying DEFAULT ''::character varying,
    cob_calle character varying DEFAULT ''::character varying,
    cob_numero character varying DEFAULT ''::character varying,
    cob_colonia character varying DEFAULT ''::character varying,
    cob_cp character varying DEFAULT ''::character varying,
    cob_entre_calles character varying DEFAULT ''::character varying,
    cob_pais_id integer DEFAULT 0,
    cob_estado_id integer DEFAULT 0,
    cob_municipio_id integer DEFAULT 0,
    cob_telefono1 character varying DEFAULT ''::character varying,
    cob_extension1 character varying DEFAULT ''::character varying,
    cob_fax character varying DEFAULT ''::character varying,
    cob_telefono2 character varying DEFAULT ''::character varying,
    cob_extension2 character varying DEFAULT ''::character varying,
    cob_email character varying DEFAULT ''::character varying,
    comentarios text DEFAULT ''::text,
    empresa_id integer DEFAULT 0,
    sucursal_id integer DEFAULT 0,
    borrado_logico boolean DEFAULT false,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    id_usuario_creacion integer DEFAULT 0,
    id_usuario_actualizacion integer DEFAULT 0,
    id_usuario_baja integer DEFAULT 0,
    ctb_cta_id_pasivo integer DEFAULT 0,
    ctb_cta_id_egreso integer DEFAULT 0,
    ctb_cta_id_ietu integer DEFAULT 0,
    ctb_cta_id_comple integer DEFAULT 0,
    ctb_cta_id_pasivo_comple integer DEFAULT 0,
    transportista boolean DEFAULT false NOT NULL
);


ALTER TABLE cxp_prov OWNER TO sumar;

--
-- Name: COLUMN cxp_prov.ctb_cta_id_pasivo; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN cxp_prov.ctb_cta_id_pasivo IS 'id de la Cuenta Contable para Pasivos';


--
-- Name: COLUMN cxp_prov.ctb_cta_id_egreso; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN cxp_prov.ctb_cta_id_egreso IS 'id de la Cuenta Contable para Egresos';


--
-- Name: COLUMN cxp_prov.ctb_cta_id_ietu; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN cxp_prov.ctb_cta_id_ietu IS 'id de la Cuenta Contable para IETU';


--
-- Name: COLUMN cxp_prov.ctb_cta_id_comple; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN cxp_prov.ctb_cta_id_comple IS 'id de la Cuenta Contable para Complementeria';


--
-- Name: COLUMN cxp_prov.ctb_cta_id_pasivo_comple; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN cxp_prov.ctb_cta_id_pasivo_comple IS 'id de la Cuenta Contable para Pasivo Complementaria';


--
-- Name: cxp_prov_clas1; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxp_prov_clas1 (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    borrado_logico boolean DEFAULT false,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0
);


ALTER TABLE cxp_prov_clas1 OWNER TO sumar;

--
-- Name: cxp_prov_clas1_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxp_prov_clas1_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxp_prov_clas1_id_seq OWNER TO sumar;

--
-- Name: cxp_prov_clas1_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxp_prov_clas1_id_seq OWNED BY cxp_prov_clas1.id;


--
-- Name: cxp_prov_clas2; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxp_prov_clas2 (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    borrado_logico boolean DEFAULT false,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0
);


ALTER TABLE cxp_prov_clas2 OWNER TO sumar;

--
-- Name: cxp_prov_clas2_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxp_prov_clas2_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxp_prov_clas2_id_seq OWNER TO sumar;

--
-- Name: cxp_prov_clas2_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxp_prov_clas2_id_seq OWNED BY cxp_prov_clas2.id;


--
-- Name: cxp_prov_clas3; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxp_prov_clas3 (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    borrado_logico boolean DEFAULT false,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0
);


ALTER TABLE cxp_prov_clas3 OWNER TO sumar;

--
-- Name: cxp_prov_clas3_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxp_prov_clas3_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxp_prov_clas3_id_seq OWNER TO sumar;

--
-- Name: cxp_prov_clas3_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxp_prov_clas3_id_seq OWNED BY cxp_prov_clas3.id;


--
-- Name: cxp_prov_clases; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxp_prov_clases (
    id integer NOT NULL,
    titulo character varying NOT NULL
);


ALTER TABLE cxp_prov_clases OWNER TO sumar;

--
-- Name: cxp_prov_clases_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxp_prov_clases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxp_prov_clases_id_seq OWNER TO sumar;

--
-- Name: cxp_prov_clases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxp_prov_clases_id_seq OWNED BY cxp_prov_clases.id;


--
-- Name: cxp_prov_contactos; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxp_prov_contactos (
    id integer NOT NULL,
    contacto character varying NOT NULL,
    proveedor_id integer NOT NULL,
    telefono character varying,
    email character varying,
    fax character varying
);


ALTER TABLE cxp_prov_contactos OWNER TO sumar;

--
-- Name: cxp_prov_contactos_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxp_prov_contactos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxp_prov_contactos_id_seq OWNER TO sumar;

--
-- Name: cxp_prov_contactos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxp_prov_contactos_id_seq OWNED BY cxp_prov_contactos.id;


--
-- Name: cxp_prov_creapar; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxp_prov_creapar (
    id integer NOT NULL,
    titulo character varying NOT NULL
);


ALTER TABLE cxp_prov_creapar OWNER TO sumar;

--
-- Name: cxp_prov_creapar_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxp_prov_creapar_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxp_prov_creapar_id_seq OWNER TO sumar;

--
-- Name: cxp_prov_creapar_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxp_prov_creapar_id_seq OWNED BY cxp_prov_creapar.id;


--
-- Name: cxp_prov_credias; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxp_prov_credias (
    id integer NOT NULL,
    descripcion text,
    dias integer
);


ALTER TABLE cxp_prov_credias OWNER TO sumar;

--
-- Name: cxp_prov_credias_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxp_prov_credias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxp_prov_credias_id_seq OWNER TO sumar;

--
-- Name: cxp_prov_credias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxp_prov_credias_id_seq OWNED BY cxp_prov_credias.id;


--
-- Name: cxp_prov_fleteras; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxp_prov_fleteras (
    id integer NOT NULL,
    razon_social character varying NOT NULL,
    borrado_logico boolean DEFAULT false NOT NULL,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    empresa_id integer DEFAULT 0,
    sucursal_id integer DEFAULT 0
);


ALTER TABLE cxp_prov_fleteras OWNER TO sumar;

--
-- Name: cxp_prov_fleteras_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxp_prov_fleteras_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxp_prov_fleteras_id_seq OWNER TO sumar;

--
-- Name: cxp_prov_fleteras_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxp_prov_fleteras_id_seq OWNED BY cxp_prov_fleteras.id;


--
-- Name: cxp_prov_grupos; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxp_prov_grupos (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    borrado_logico boolean
);


ALTER TABLE cxp_prov_grupos OWNER TO sumar;

--
-- Name: cxp_prov_grupos_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxp_prov_grupos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxp_prov_grupos_id_seq OWNER TO sumar;

--
-- Name: cxp_prov_grupos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxp_prov_grupos_id_seq OWNED BY cxp_prov_grupos.id;


--
-- Name: cxp_prov_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxp_prov_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxp_prov_id_seq OWNER TO sumar;

--
-- Name: cxp_prov_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxp_prov_id_seq OWNED BY cxp_prov.id;


--
-- Name: cxp_prov_tipos_embarque; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxp_prov_tipos_embarque (
    id integer NOT NULL,
    titulo character varying NOT NULL
);


ALTER TABLE cxp_prov_tipos_embarque OWNER TO sumar;

--
-- Name: cxp_prov_tipos_embarque_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxp_prov_tipos_embarque_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxp_prov_tipos_embarque_id_seq OWNER TO sumar;

--
-- Name: cxp_prov_tipos_embarque_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxp_prov_tipos_embarque_id_seq OWNED BY cxp_prov_tipos_embarque.id;


--
-- Name: cxp_prov_zonas; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE cxp_prov_zonas (
    id integer NOT NULL,
    titulo character varying NOT NULL
);


ALTER TABLE cxp_prov_zonas OWNER TO sumar;

--
-- Name: cxp_prov_zonas_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE cxp_prov_zonas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE cxp_prov_zonas_id_seq OWNER TO sumar;

--
-- Name: cxp_prov_zonas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE cxp_prov_zonas_id_seq OWNED BY cxp_prov_zonas.id;


--
-- Name: erp_clients_consignacions; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE erp_clients_consignacions (
    id integer NOT NULL,
    cliente_id integer NOT NULL,
    calle character varying NOT NULL,
    numero character varying NOT NULL,
    colonia character varying NOT NULL,
    pais character varying,
    entidad character varying,
    localidad character varying,
    cp character varying NOT NULL,
    localidad_alternativa character varying,
    telefono character varying,
    fax character varying,
    momento_creacion timestamp with time zone NOT NULL,
    pais_id integer,
    estado_id integer,
    municipio_id integer
);


ALTER TABLE erp_clients_consignacions OWNER TO sumar;

--
-- Name: erp_clients_consignacions_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE erp_clients_consignacions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE erp_clients_consignacions_id_seq OWNER TO sumar;

--
-- Name: erp_clients_consignacions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE erp_clients_consignacions_id_seq OWNED BY erp_clients_consignacions.id;


--
-- Name: erp_h_facturas; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE erp_h_facturas (
    id integer NOT NULL,
    cliente_id integer NOT NULL,
    serie_folio character varying NOT NULL,
    monto_total double precision NOT NULL,
    moneda_id integer NOT NULL,
    tipo_cambio double precision NOT NULL,
    pagado boolean DEFAULT false NOT NULL,
    total_pagos double precision DEFAULT 0,
    total_pagos_cancelados double precision DEFAULT 0,
    saldo_factura double precision DEFAULT 0,
    total_notas_creditos double precision DEFAULT 0,
    total_saldoa_favor double precision DEFAULT 0,
    total_anticipos double precision DEFAULT 0,
    momento_facturacion timestamp with time zone,
    cancelacion boolean DEFAULT false NOT NULL,
    momento_cancelacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    id_usuario_creacion integer DEFAULT 0,
    id_usuario_cancelacion integer DEFAULT 0,
    empresa_id integer DEFAULT 0,
    sucursal_id integer DEFAULT 0,
    fac_docs_tipo_cancelacion_id integer,
    cxc_agen_id integer DEFAULT 0,
    fecha_vencimiento timestamp with time zone,
    estatus_revision smallint DEFAULT 0,
    orden_compra character varying DEFAULT ''::character varying,
    enviado boolean DEFAULT false,
    fecha_ultimo_pago date,
    subtotal double precision DEFAULT 0,
    impuesto double precision DEFAULT 0,
    retencion double precision DEFAULT 0,
    monto_ieps double precision DEFAULT 0
);


ALTER TABLE erp_h_facturas OWNER TO sumar;

--
-- Name: COLUMN erp_h_facturas.estatus_revision; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN erp_h_facturas.estatus_revision IS '0=Sin estatus, 1=Revision, 2=Cobro';


--
-- Name: COLUMN erp_h_facturas.enviado; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN erp_h_facturas.enviado IS 'Valor TRUE=Enviado a ruta para Revision o Cobro';


--
-- Name: COLUMN erp_h_facturas.fecha_ultimo_pago; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN erp_h_facturas.fecha_ultimo_pago IS 'Esta es la fecha de deposito del ultimo pago';


--
-- Name: erp_h_facturas_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE erp_h_facturas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE erp_h_facturas_id_seq OWNER TO sumar;

--
-- Name: erp_h_facturas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE erp_h_facturas_id_seq OWNED BY erp_h_facturas.id;


--
-- Name: erp_mascaras_para_validaciones_por_app; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE erp_mascaras_para_validaciones_por_app (
    app_id integer NOT NULL,
    mask_name character varying NOT NULL,
    mask_regex character varying,
    id integer NOT NULL
);


ALTER TABLE erp_mascaras_para_validaciones_por_app OWNER TO sumar;

--
-- Name: erp_mascaras_para_validaciones_por_app_app_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE erp_mascaras_para_validaciones_por_app_app_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE erp_mascaras_para_validaciones_por_app_app_id_seq OWNER TO sumar;

--
-- Name: erp_mascaras_para_validaciones_por_app_app_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE erp_mascaras_para_validaciones_por_app_app_id_seq OWNED BY erp_mascaras_para_validaciones_por_app.app_id;


--
-- Name: erp_monedavers; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: erp_pagos_formas; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE erp_pagos_formas (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    borrado_logico boolean
);


ALTER TABLE erp_pagos_formas OWNER TO sumar;

--
-- Name: erp_pagos_formas_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE erp_pagos_formas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE erp_pagos_formas_id_seq OWNER TO sumar;

--
-- Name: erp_pagos_formas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE erp_pagos_formas_id_seq OWNED BY erp_pagos_formas.id;


--
-- Name: erp_parametros_generales; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE erp_parametros_generales (
    id integer NOT NULL,
    variable character varying NOT NULL,
    valor text NOT NULL
);


ALTER TABLE erp_parametros_generales OWNER TO sumar;

--
-- Name: erp_parametros_generales_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE erp_parametros_generales_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE erp_parametros_generales_id_seq OWNER TO sumar;

--
-- Name: erp_parametros_generales_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE erp_parametros_generales_id_seq OWNED BY erp_parametros_generales.id;


--
-- Name: erp_prefacturas; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE erp_prefacturas (
    id integer NOT NULL,
    cliente_id integer NOT NULL,
    moneda_id integer,
    observaciones text,
    subtotal double precision,
    impuesto double precision,
    total double precision,
    proceso_id integer NOT NULL,
    borrado_logico boolean DEFAULT false,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    tipo_cambio double precision DEFAULT 0,
    id_usuario_creacion integer DEFAULT 0,
    id_usuario_actualizacion integer DEFAULT 0,
    id_usuario_baja integer DEFAULT 0,
    empleado_id integer DEFAULT 0,
    terminos_id integer DEFAULT 0,
    orden_compra character varying DEFAULT ''::character varying,
    factura_sai character varying DEFAULT ''::character varying,
    factura_id integer,
    refacturar boolean DEFAULT false,
    fac_metodos_pago_id integer DEFAULT 0,
    no_cuenta character varying DEFAULT ''::character varying,
    monto_retencion double precision DEFAULT 0,
    tasa_retencion_immex double precision DEFAULT 0,
    tipo_documento smallint DEFAULT 0,
    folio_pedido character varying DEFAULT ''::character varying,
    enviar_ruta boolean DEFAULT false,
    inv_alm_id smallint DEFAULT 0,
    id_moneda_pedido integer DEFAULT 0,
    cxc_clie_df_id integer DEFAULT 0,
    fac_subtotal double precision DEFAULT 0 NOT NULL,
    fac_impuesto double precision DEFAULT 0 NOT NULL,
    fac_monto_retencion double precision DEFAULT 0 NOT NULL,
    fac_total double precision DEFAULT 0 NOT NULL,
    monto_ieps double precision DEFAULT 0,
    fac_monto_ieps double precision DEFAULT 0,
    monto_descto double precision DEFAULT 0 NOT NULL,
    fac_monto_descto double precision DEFAULT 0 NOT NULL,
    motivo_descto character varying DEFAULT ''::character varying,
    ctb_tmov_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE erp_prefacturas OWNER TO sumar;

--
-- Name: COLUMN erp_prefacturas.tipo_documento; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN erp_prefacturas.tipo_documento IS '1=Factura, 2=Remision, 3=Factura de Remision';


--
-- Name: COLUMN erp_prefacturas.enviar_ruta; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN erp_prefacturas.enviar_ruta IS 'True=Debe aparecer en la busqueda de facturas para agregar a la ruta. False=No debe aparecer en la busqueda.';


--
-- Name: COLUMN erp_prefacturas.inv_alm_id; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN erp_prefacturas.inv_alm_id IS 'Almacen de donde se le dara salida los productos al facturar';


--
-- Name: COLUMN erp_prefacturas.id_moneda_pedido; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN erp_prefacturas.id_moneda_pedido IS 'Moneda original con el que se hizo el pedido, puede ser diferente a la moneda de la factura';


--
-- Name: COLUMN erp_prefacturas.cxc_clie_df_id; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN erp_prefacturas.cxc_clie_df_id IS 'ID de la Direccion Fiscal(cxc_clie_df) para la Facturacion. Si el valor de este campo es 0, entonces por default toma la direccion de la tabla de Clientes (cxc_clie)';


--
-- Name: COLUMN erp_prefacturas.fac_subtotal; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN erp_prefacturas.fac_subtotal IS 'Subtotal a Facturar o Remisionar, una vez finalizado en proceso este campo se queda en cero.';


--
-- Name: COLUMN erp_prefacturas.fac_impuesto; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN erp_prefacturas.fac_impuesto IS 'Impuesto de la Factura o Remision, una vez finalizado en proceso este campo se queda en cero.';


--
-- Name: COLUMN erp_prefacturas.fac_monto_retencion; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN erp_prefacturas.fac_monto_retencion IS 'Monto de la retencion de la Factura o Remision, una vez finalizado en proceso este campo se queda en cero.';


--
-- Name: COLUMN erp_prefacturas.fac_total; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN erp_prefacturas.fac_total IS 'Total de la Factura o Remision, una vez finalizado en proceso este campo se queda en cero.';


--
-- Name: erp_prefacturas_detalles; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE erp_prefacturas_detalles (
    id integer NOT NULL,
    prefacturas_id integer,
    producto_id integer NOT NULL,
    presentacion_id integer NOT NULL,
    tipo_impuesto_id integer DEFAULT 0,
    cantidad double precision,
    precio_unitario double precision NOT NULL,
    momento_creacion timestamp with time zone,
    valor_imp double precision DEFAULT 0,
    costo_promedio double precision DEFAULT 0,
    reservado double precision DEFAULT 0,
    costo_referencia double precision DEFAULT 0,
    cant_facturado double precision DEFAULT 0 NOT NULL,
    facturado boolean DEFAULT false NOT NULL,
    cant_facturar double precision DEFAULT 0 NOT NULL,
    inv_prod_unidad_id integer DEFAULT 0 NOT NULL,
    gral_ieps_id integer DEFAULT 0,
    valor_ieps double precision DEFAULT 0,
    descto double precision DEFAULT 0,
    fac_rem_det_id integer DEFAULT 0,
    gral_imptos_ret_id integer DEFAULT 0 NOT NULL,
    tasa_ret double precision DEFAULT 0 NOT NULL
);


ALTER TABLE erp_prefacturas_detalles OWNER TO sumar;

--
-- Name: COLUMN erp_prefacturas_detalles.costo_promedio; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN erp_prefacturas_detalles.costo_promedio IS 'El costo promedio solo se guarda en esta tabla cuando la prefactura viene de una o varias Remisiones.';


--
-- Name: COLUMN erp_prefacturas_detalles.reservado; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN erp_prefacturas_detalles.reservado IS 'Cantidad que se reservo en inv_exi al crear el pedido';


--
-- Name: COLUMN erp_prefacturas_detalles.costo_referencia; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN erp_prefacturas_detalles.costo_referencia IS 'El costo referencia solo se guarda en esta tabla cuando la prefactura viene de una o varias Remisiones.';


--
-- Name: COLUMN erp_prefacturas_detalles.cant_facturado; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN erp_prefacturas_detalles.cant_facturado IS 'Cantidad que se ha facturado de esta partida';


--
-- Name: COLUMN erp_prefacturas_detalles.facturado; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN erp_prefacturas_detalles.facturado IS 'Este campo indica cuando la partida ha sido facturado totalmente. TRUE=La partida esta facturada completamente, FALSE=La partida no se ha facturado en su totalidad.';


--
-- Name: COLUMN erp_prefacturas_detalles.cant_facturar; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN erp_prefacturas_detalles.cant_facturar IS 'Cantidad a Facturar o Remisionar, una vez realizado el proceso, este campo debe quedar en cero.';


--
-- Name: COLUMN erp_prefacturas_detalles.inv_prod_unidad_id; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN erp_prefacturas_detalles.inv_prod_unidad_id IS 'Id de la unidad de medida de venta, puede ser diferente a la unidad de medida en el catalogo de productos.';


--
-- Name: erp_prefacturas_detalles_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE erp_prefacturas_detalles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE erp_prefacturas_detalles_id_seq OWNER TO sumar;

--
-- Name: erp_prefacturas_detalles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE erp_prefacturas_detalles_id_seq OWNED BY erp_prefacturas_detalles.id;


--
-- Name: erp_prefacturas_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE erp_prefacturas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE erp_prefacturas_id_seq OWNER TO sumar;

--
-- Name: erp_prefacturas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE erp_prefacturas_id_seq OWNED BY erp_prefacturas.id;


--
-- Name: erp_proceso; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE erp_proceso (
    id integer NOT NULL,
    proceso_flujo_id integer NOT NULL,
    empresa_id integer DEFAULT 0,
    sucursal_id integer DEFAULT 0
);


ALTER TABLE erp_proceso OWNER TO sumar;

--
-- Name: erp_proceso_flujo; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE erp_proceso_flujo (
    id integer NOT NULL,
    titulo character varying NOT NULL
);


ALTER TABLE erp_proceso_flujo OWNER TO sumar;

--
-- Name: erp_proceso_flujo_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE erp_proceso_flujo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE erp_proceso_flujo_id_seq OWNER TO sumar;

--
-- Name: erp_proceso_flujo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE erp_proceso_flujo_id_seq OWNED BY erp_proceso_flujo.id;


--
-- Name: erp_proceso_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE erp_proceso_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE erp_proceso_id_seq OWNER TO sumar;

--
-- Name: erp_proceso_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE erp_proceso_id_seq OWNED BY erp_proceso.id;


--
-- Name: erp_tiempos_entrega; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE erp_tiempos_entrega (
    id integer NOT NULL,
    descripcion character varying NOT NULL
);


ALTER TABLE erp_tiempos_entrega OWNER TO sumar;

--
-- Name: erp_tiempos_entrega_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE erp_tiempos_entrega_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE erp_tiempos_entrega_id_seq OWNER TO sumar;

--
-- Name: erp_tiempos_entrega_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE erp_tiempos_entrega_id_seq OWNED BY erp_tiempos_entrega.id;


--
-- Name: fac_cfds_conf; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE fac_cfds_conf (
    empresa_id integer NOT NULL,
    archivo_certificado character varying,
    numero_certificado character varying,
    archivo_llave character varying,
    password_llave character varying,
    id integer NOT NULL,
    gral_suc_id integer DEFAULT 0 NOT NULL,
    archivo_xsl character varying DEFAULT ''::character varying,
    archivo_xsd_cfdi character varying DEFAULT ''::character varying,
    archivo_wsdl_timbrado_cfdi character varying DEFAULT ''::character varying,
    ws_pfx_cert character varying DEFAULT ''::character varying,
    passwd_ws_pfx character varying DEFAULT ''::character varying,
    javavm_dir character varying DEFAULT ''::character varying,
    javavm_cacerts character varying DEFAULT ''::character varying,
    archivo_xsl_cadena_timbre character varying DEFAULT ''::character varying,
    usuario character varying DEFAULT ''::character varying,
    contrasena character varying DEFAULT ''::character varying,
    archivo_xsl_cadena_ctas_contables character varying DEFAULT ''::character varying,
    archivo_xsd_ctas_contables character varying DEFAULT ''::character varying,
    archivo_xsl_cadena_balanza_comprobacion character varying DEFAULT ''::character varying NOT NULL
);


ALTER TABLE fac_cfds_conf OWNER TO sumar;

--
-- Name: COLUMN fac_cfds_conf.archivo_certificado; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN fac_cfds_conf.archivo_certificado IS 'Archivo de la llave pública del CSD que deberá estar incluida en el archivo CFD y CFDI con Timbre Fiscal en el atributo "certificado" y codificada en base64. No aplica para CFDI con Conector Fiscal.';


--
-- Name: COLUMN fac_cfds_conf.numero_certificado; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN fac_cfds_conf.numero_certificado IS 'Información del número de certificado que se está utilizando para el firmado del comprobante CFD y  CFDI con Timbre Fiscal. No aplica para CFDI con Conector Fiscal.';


--
-- Name: COLUMN fac_cfds_conf.archivo_llave; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN fac_cfds_conf.archivo_llave IS 'Archivo de la llave privada del CSD que se utiliza para el firmado de la cadena original del CFD y  CFDI con Timbre Fiscal. No aplica para CFDI con Conector Fiscal.';


--
-- Name: COLUMN fac_cfds_conf.password_llave; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN fac_cfds_conf.password_llave IS 'Contraseña de la llave privada del CSD para el firmado de la cadena original del CFD y  CFDI con Timbre Fiscal. No aplica para CFDI con Conector Fiscal.';


--
-- Name: COLUMN fac_cfds_conf.archivo_xsl; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN fac_cfds_conf.archivo_xsl IS 'Hoja de estilos para el armado correcto de la cadena original del CFD y  CFDI con Timbre Fiscal. No aplica para CFDI con Conector Fiscal.';


--
-- Name: COLUMN fac_cfds_conf.archivo_xsd_cfdi; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN fac_cfds_conf.archivo_xsd_cfdi IS 'Archivo de esquema del CFDi 3.2. El esquema es para CFDI con Timbre Fiscal.';


--
-- Name: COLUMN fac_cfds_conf.archivo_wsdl_timbrado_cfdi; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN fac_cfds_conf.archivo_wsdl_timbrado_cfdi IS 'Archivo WSDL, contiene la definición del servicio web que deberá invocar el desarrollo y así utilizar el servicio de timbre fiscal. Solo para facturacion con Timbre Fiscal.';


--
-- Name: COLUMN fac_cfds_conf.archivo_xsl_cadena_timbre; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN fac_cfds_conf.archivo_xsl_cadena_timbre IS 'Fichero xslt para obtener la cadena original del Complemento del Timbre Fiscal del CFDI';


--
-- Name: COLUMN fac_cfds_conf.usuario; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN fac_cfds_conf.usuario IS 'Nombre de Usuario para conexion a WS ServiSim';


--
-- Name: COLUMN fac_cfds_conf.contrasena; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN fac_cfds_conf.contrasena IS 'Contraseña de Usuario para conexion a WS ServiSim';


--
-- Name: COLUMN fac_cfds_conf.archivo_xsl_cadena_ctas_contables; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN fac_cfds_conf.archivo_xsl_cadena_ctas_contables IS 'Fichero xslt para obtener la cadena original del Xml de Cuentas COntables';


--
-- Name: COLUMN fac_cfds_conf.archivo_xsd_ctas_contables; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN fac_cfds_conf.archivo_xsd_ctas_contables IS 'Fichero xsd para validar el Xml de Cuentas Contables';


--
-- Name: fac_cfds_conf_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE fac_cfds_conf_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fac_cfds_conf_id_seq OWNER TO sumar;

--
-- Name: fac_cfds_conf_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE fac_cfds_conf_id_seq OWNED BY fac_cfds_conf.id;


--
-- Name: fac_metodos_pago; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE fac_metodos_pago (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    borrado_logico boolean DEFAULT false,
    clave_sat character varying DEFAULT ''::character varying NOT NULL,
    momento_creacion timestamp with time zone DEFAULT now() NOT NULL,
    momento_actualiza timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0,
    gral_emp_id integer DEFAULT 0
);


ALTER TABLE fac_metodos_pago OWNER TO sumar;

--
-- Name: fac_metodos_pago_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE fac_metodos_pago_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fac_metodos_pago_id_seq OWNER TO sumar;

--
-- Name: fac_metodos_pago_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE fac_metodos_pago_id_seq OWNED BY fac_metodos_pago.id;


--
-- Name: fac_namespaces; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE fac_namespaces (
    id integer NOT NULL,
    key_xmlns character varying DEFAULT ''::character varying,
    xmlns character varying DEFAULT ''::character varying,
    schemalocation character varying DEFAULT ''::character varying,
    fac boolean DEFAULT false NOT NULL,
    fac_nomina boolean DEFAULT false NOT NULL,
    derogado boolean DEFAULT false NOT NULL,
    fecha_derogacion date
);


ALTER TABLE fac_namespaces OWNER TO sumar;

--
-- Name: fac_namespaces_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE fac_namespaces_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fac_namespaces_id_seq OWNER TO sumar;

--
-- Name: fac_namespaces_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE fac_namespaces_id_seq OWNED BY fac_namespaces.id;


--
-- Name: fac_nomina; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE fac_nomina (
    id integer NOT NULL,
    tipo_comprobante character varying DEFAULT ''::character varying,
    forma_pago character varying DEFAULT ''::character varying,
    tipo_cambio double precision DEFAULT 0,
    no_cuenta character varying DEFAULT ''::character varying,
    fecha_pago date,
    fac_metodos_pago_id integer DEFAULT 0,
    gral_mon_id integer DEFAULT 0,
    nom_periodicidad_pago_id integer DEFAULT 0,
    nom_periodos_conf_det_id integer DEFAULT 0,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0,
    status integer DEFAULT 0 NOT NULL,
    CONSTRAINT chk_fac_nomina_status CHECK ((status = ANY (ARRAY[0, 1, 2])))
);


ALTER TABLE fac_nomina OWNER TO sumar;

--
-- Name: COLUMN fac_nomina.status; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN fac_nomina.status IS '0=No se ha generado CFDI de ningun registro, 1=Se ha generado CFDI de por lo menos un registro, 2=Se han generado CFDI de todos los registros';


--
-- Name: fac_nomina_det; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE fac_nomina_det (
    id integer NOT NULL,
    fac_nomina_id integer DEFAULT 0 NOT NULL,
    gral_empleado_id integer DEFAULT 0 NOT NULL,
    no_empleado character varying DEFAULT ''::character varying,
    rfc character varying DEFAULT ''::character varying,
    nombre character varying DEFAULT ''::character varying,
    curp character varying DEFAULT ''::character varying,
    gral_depto_id integer DEFAULT 0,
    gral_puesto_id integer DEFAULT 0,
    fecha_contrato date,
    antiguedad integer DEFAULT 0,
    nom_regimen_contratacion_id integer DEFAULT 0,
    nom_tipo_contrato_id integer DEFAULT 0,
    nom_tipo_jornada_id integer DEFAULT 0,
    nom_periodicidad_pago_id integer DEFAULT 0,
    clabe character varying DEFAULT ''::character varying,
    tes_ban_id integer DEFAULT 0,
    nom_riesgo_puesto_id integer DEFAULT 0,
    imss character varying DEFAULT ''::character varying,
    reg_patronal character varying DEFAULT ''::character varying,
    salario_base double precision DEFAULT 0,
    salario_integrado double precision DEFAULT 0,
    fecha_ini_pago date,
    fecha_fin_pago date,
    no_dias_pago integer DEFAULT 0,
    concepto_descripcion character varying DEFAULT ''::character varying,
    concepto_unidad character varying DEFAULT ''::character varying,
    concepto_cantidad double precision DEFAULT 0,
    concepto_valor_unitario double precision DEFAULT 0,
    concepto_importe double precision DEFAULT 0,
    descuento double precision DEFAULT 0,
    motivo_descuento character varying DEFAULT ''::character varying,
    gral_isr_id integer DEFAULT 0,
    importe_retencion double precision DEFAULT 0,
    comp_subtotal double precision DEFAULT 0,
    comp_descuento double precision DEFAULT 0,
    comp_retencion double precision DEFAULT 0,
    comp_total double precision DEFAULT 0,
    percep_total_gravado double precision DEFAULT 0,
    percep_total_excento double precision DEFAULT 0,
    deduc_total_gravado double precision DEFAULT 0,
    deduc_total_excento double precision DEFAULT 0,
    facturado boolean DEFAULT false NOT NULL,
    momento_facturacion timestamp with time zone,
    gral_usr_id_facturacion integer,
    validado boolean DEFAULT false NOT NULL,
    serie character varying DEFAULT ''::character varying NOT NULL,
    folio character varying DEFAULT ''::character varying NOT NULL,
    ref_id character varying DEFAULT ''::character varying NOT NULL,
    cancelado boolean DEFAULT false NOT NULL,
    momento_cancelacion timestamp with time zone,
    gral_usr_id_cancela integer DEFAULT 0
);


ALTER TABLE fac_nomina_det OWNER TO sumar;

--
-- Name: fac_nomina_det_deduc; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE fac_nomina_det_deduc (
    id integer NOT NULL,
    fac_nomina_det_id integer NOT NULL,
    nom_deduc_id integer NOT NULL,
    gravado double precision,
    excento double precision
);


ALTER TABLE fac_nomina_det_deduc OWNER TO sumar;

--
-- Name: fac_nomina_det_deduc_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE fac_nomina_det_deduc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fac_nomina_det_deduc_id_seq OWNER TO sumar;

--
-- Name: fac_nomina_det_deduc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE fac_nomina_det_deduc_id_seq OWNED BY fac_nomina_det_deduc.id;


--
-- Name: fac_nomina_det_hrs_extra; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE fac_nomina_det_hrs_extra (
    id integer NOT NULL,
    fac_nomina_det_id integer NOT NULL,
    nom_tipo_hrs_extra_id integer NOT NULL,
    no_dias double precision,
    no_hrs double precision,
    importe double precision
);


ALTER TABLE fac_nomina_det_hrs_extra OWNER TO sumar;

--
-- Name: fac_nomina_det_hrs_extra_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE fac_nomina_det_hrs_extra_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fac_nomina_det_hrs_extra_id_seq OWNER TO sumar;

--
-- Name: fac_nomina_det_hrs_extra_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE fac_nomina_det_hrs_extra_id_seq OWNED BY fac_nomina_det_hrs_extra.id;


--
-- Name: fac_nomina_det_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE fac_nomina_det_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fac_nomina_det_id_seq OWNER TO sumar;

--
-- Name: fac_nomina_det_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE fac_nomina_det_id_seq OWNED BY fac_nomina_det.id;


--
-- Name: fac_nomina_det_incapa; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE fac_nomina_det_incapa (
    id integer NOT NULL,
    fac_nomina_det_id integer NOT NULL,
    nom_tipo_incapacidad_id integer NOT NULL,
    no_dias double precision,
    importe double precision
);


ALTER TABLE fac_nomina_det_incapa OWNER TO sumar;

--
-- Name: fac_nomina_det_incapa_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE fac_nomina_det_incapa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fac_nomina_det_incapa_id_seq OWNER TO sumar;

--
-- Name: fac_nomina_det_incapa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE fac_nomina_det_incapa_id_seq OWNED BY fac_nomina_det_incapa.id;


--
-- Name: fac_nomina_det_percep; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE fac_nomina_det_percep (
    id integer NOT NULL,
    fac_nomina_det_id integer NOT NULL,
    nom_percep_id integer NOT NULL,
    gravado double precision,
    excento double precision
);


ALTER TABLE fac_nomina_det_percep OWNER TO sumar;

--
-- Name: fac_nomina_det_percep_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE fac_nomina_det_percep_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fac_nomina_det_percep_id_seq OWNER TO sumar;

--
-- Name: fac_nomina_det_percep_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE fac_nomina_det_percep_id_seq OWNED BY fac_nomina_det_percep.id;


--
-- Name: fac_nomina_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE fac_nomina_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fac_nomina_id_seq OWNER TO sumar;

--
-- Name: fac_nomina_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE fac_nomina_id_seq OWNED BY fac_nomina.id;


--
-- Name: fac_nomina_par; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE fac_nomina_par (
    id integer NOT NULL,
    gral_emp_id integer NOT NULL,
    gral_suc_id integer NOT NULL,
    tipo_comprobante character varying DEFAULT ''::character varying,
    forma_pago character varying DEFAULT ''::character varying,
    no_cuenta_pago character varying DEFAULT ''::character varying,
    gral_mon_id integer DEFAULT 1 NOT NULL,
    gral_isr_id integer DEFAULT 0 NOT NULL,
    motivo_descuento character varying DEFAULT ''::character varying,
    concepto_unidad character varying DEFAULT ''::character varying,
    leyenda character varying DEFAULT ''::character varying
);


ALTER TABLE fac_nomina_par OWNER TO sumar;

--
-- Name: COLUMN fac_nomina_par.gral_mon_id; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN fac_nomina_par.gral_mon_id IS 'Moneda para la Nomina';


--
-- Name: COLUMN fac_nomina_par.concepto_unidad; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN fac_nomina_par.concepto_unidad IS 'Unidad que se debe mostrar por default para el concepto';


--
-- Name: fac_nomina_par_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE fac_nomina_par_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fac_nomina_par_id_seq OWNER TO sumar;

--
-- Name: fac_nomina_par_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE fac_nomina_par_id_seq OWNED BY fac_nomina_par.id;


--
-- Name: fac_par; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE fac_par (
    id integer NOT NULL,
    gral_suc_id integer NOT NULL,
    cxc_mov_tipo_id integer NOT NULL,
    inv_alm_id integer NOT NULL,
    permitir_pedido boolean DEFAULT true,
    permitir_remision boolean DEFAULT true,
    permitir_cambio_almacen boolean DEFAULT true,
    permitir_servicios boolean DEFAULT true,
    permitir_articulos boolean DEFAULT true,
    permitir_kits boolean DEFAULT true,
    gral_suc_id_consecutivo integer NOT NULL,
    borrado_logico boolean DEFAULT false NOT NULL,
    momento_creacion timestamp with time zone NOT NULL,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0,
    gral_emp_id integer NOT NULL,
    formato_pedido smallint DEFAULT 1 NOT NULL,
    formato_factura smallint DEFAULT 1 NOT NULL,
    validar_pres_pedido boolean DEFAULT true NOT NULL,
    cambiar_unidad_medida boolean DEFAULT false NOT NULL,
    incluye_adenda boolean DEFAULT false NOT NULL,
    gral_emails_id_envio integer DEFAULT 0,
    gral_emails_id_cco integer DEFAULT 0,
    permitir_descto boolean DEFAULT false NOT NULL,
    permitir_req_com boolean DEFAULT false NOT NULL,
    aut_precio_menor_cot boolean DEFAULT false NOT NULL,
    aut_precio_menor_ped boolean DEFAULT false NOT NULL
);


ALTER TABLE fac_par OWNER TO sumar;

--
-- Name: TABLE fac_par; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON TABLE fac_par IS 'Aqui se definen los parametros para la facturacion. La definicion de parametros es por Sucursal.';


--
-- Name: COLUMN fac_par.gral_suc_id_consecutivo; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN fac_par.gral_suc_id_consecutivo IS 'Aqui se guarda el id de la sucursal del que se tomara el consecutivo para generar el folio del pedido.';


--
-- Name: COLUMN fac_par.formato_pedido; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN fac_par.formato_pedido IS '1=Formato 1(Hoja completa), 2=Formato 2(Media hoja)';


--
-- Name: COLUMN fac_par.validar_pres_pedido; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN fac_par.validar_pres_pedido IS 'TRUE=Validar Existencias de Presentaciones al Crear el Pedido, FALSE=No validar existencia de Presentaciones al crear y confirmar el pedido.';


--
-- Name: COLUMN fac_par.cambiar_unidad_medida; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN fac_par.cambiar_unidad_medida IS 'Indica si se debe permitir al usuario cambiar la unidad de medida del producto al momento de crear el pedido.';


--
-- Name: fac_par_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE fac_par_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE fac_par_id_seq OWNER TO sumar;

--
-- Name: fac_par_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE fac_par_id_seq OWNED BY fac_par.id;


--
-- Name: gral_app; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE gral_app (
    id integer NOT NULL,
    descripcion character varying NOT NULL,
    nombre_app character varying,
    tipo smallint
);


ALTER TABLE gral_app OWNER TO sumar;

--
-- Name: TABLE gral_app; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON TABLE gral_app IS 'Aqui estan dadas de alta, todas las aplicaciones de las cuales dispone actualmente el sistema. ';


--
-- Name: COLUMN gral_app.id; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN gral_app.id IS 'Identificador de la aplicacion, cada aplicacion tiene un identificador unico representador por un entero';


--
-- Name: gral_app_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_app_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_app_id_seq OWNER TO sumar;

--
-- Name: gral_app_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_app_id_seq OWNED BY gral_app.id;


--
-- Name: gral_categ; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: gral_civils; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: gral_cons; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE gral_cons (
    id integer NOT NULL,
    gral_emp_id integer NOT NULL,
    gral_suc_id integer NOT NULL,
    gral_cons_tipo_id integer NOT NULL,
    prefijo character varying DEFAULT ''::character varying,
    consecutivo bigint DEFAULT 0,
    borrado_logico boolean DEFAULT false
);


ALTER TABLE gral_cons OWNER TO sumar;

--
-- Name: gral_cons_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_cons_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_cons_id_seq OWNER TO sumar;

--
-- Name: gral_cons_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_cons_id_seq OWNED BY gral_cons.id;


--
-- Name: gral_cons_tipos; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE gral_cons_tipos (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    borrado_logico boolean DEFAULT false
);


ALTER TABLE gral_cons_tipos OWNER TO sumar;

--
-- Name: TABLE gral_cons_tipos; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON TABLE gral_cons_tipos IS 'Tabla de tipos de consecutivos';


--
-- Name: gral_cons_tipos_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_cons_tipos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_cons_tipos_id_seq OWNER TO sumar;

--
-- Name: gral_cons_tipos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_cons_tipos_id_seq OWNED BY gral_cons_tipos.id;


--
-- Name: gral_deptos; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: gral_deptos_turnos; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE gral_deptos_turnos (
    id integer NOT NULL,
    gral_deptos_id integer NOT NULL,
    turno integer NOT NULL,
    hora_ini time with time zone NOT NULL,
    hora_fin time with time zone NOT NULL,
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


ALTER TABLE gral_deptos_turnos OWNER TO sumar;

--
-- Name: TABLE gral_deptos_turnos; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON TABLE gral_deptos_turnos IS 'Turnos por Departamento';


--
-- Name: COLUMN gral_deptos_turnos.id; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN gral_deptos_turnos.id IS 'llave primaria ID de la tabla';


--
-- Name: COLUMN gral_deptos_turnos.gral_deptos_id; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN gral_deptos_turnos.gral_deptos_id IS 'num de departamento';


--
-- Name: COLUMN gral_deptos_turnos.turno; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN gral_deptos_turnos.turno IS 'numero de turno';


--
-- Name: COLUMN gral_deptos_turnos.hora_ini; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN gral_deptos_turnos.hora_ini IS 'hora inicial del turno';


--
-- Name: COLUMN gral_deptos_turnos.hora_fin; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN gral_deptos_turnos.hora_fin IS 'hora final del turno';


--
-- Name: gral_deptos_turnos_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_deptos_turnos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_deptos_turnos_id_seq OWNER TO sumar;

--
-- Name: gral_deptos_turnos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_deptos_turnos_id_seq OWNED BY gral_deptos_turnos.id;


--
-- Name: gral_dias_no_laborables; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE gral_dias_no_laborables (
    id integer NOT NULL,
    fecha_no_laborable date,
    descripcion character varying,
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


ALTER TABLE gral_dias_no_laborables OWNER TO sumar;

--
-- Name: gral_dias_no_laborables_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_dias_no_laborables_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_dias_no_laborables_id_seq OWNER TO sumar;

--
-- Name: gral_dias_no_laborables_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_dias_no_laborables_id_seq OWNED BY gral_dias_no_laborables.id;


--
-- Name: gral_edo; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: gral_emails; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: gral_emp; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: gral_emp_leyenda; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: gral_empleado_deduc; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE gral_empleado_deduc (
    id integer NOT NULL,
    gral_empleado_id integer NOT NULL,
    nom_deduc_id integer NOT NULL
);


ALTER TABLE gral_empleado_deduc OWNER TO sumar;

--
-- Name: gral_empleado_deduc_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_empleado_deduc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_empleado_deduc_id_seq OWNER TO sumar;

--
-- Name: gral_empleado_deduc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_empleado_deduc_id_seq OWNED BY gral_empleado_deduc.id;


--
-- Name: gral_empleado_percep; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE gral_empleado_percep (
    id integer NOT NULL,
    gral_empleado_id integer NOT NULL,
    nom_percep_id integer NOT NULL
);


ALTER TABLE gral_empleado_percep OWNER TO sumar;

--
-- Name: gral_empleado_percep_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_empleado_percep_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_empleado_percep_id_seq OWNER TO sumar;

--
-- Name: gral_empleado_percep_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_empleado_percep_id_seq OWNED BY gral_empleado_percep.id;


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
-- Name: gral_escolaridads; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: gral_ieps; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE gral_ieps (
    id integer NOT NULL,
    titulo character varying DEFAULT ''::character varying NOT NULL,
    descripcion character varying NOT NULL,
    tasa double precision DEFAULT 0,
    borrado_logico boolean DEFAULT false NOT NULL,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_usr_id_crea integer DEFAULT 0,
    gral_usr_id_actualiza integer DEFAULT 0,
    gral_usr_id_cancela integer DEFAULT 0,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0
);


ALTER TABLE gral_ieps OWNER TO sumar;

--
-- Name: gral_ieps_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_ieps_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_ieps_id_seq OWNER TO sumar;

--
-- Name: gral_ieps_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_ieps_id_seq OWNED BY gral_ieps.id;


--
-- Name: gral_imptos; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: gral_imptos_ret; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE gral_imptos_ret (
    id integer NOT NULL,
    titulo character varying DEFAULT ''::character varying NOT NULL,
    descripcion character varying DEFAULT ''::character varying NOT NULL,
    tasa double precision DEFAULT 0,
    borrado_logico boolean DEFAULT false NOT NULL,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_usr_id_crea integer DEFAULT 0,
    gral_usr_id_actualiza integer DEFAULT 0,
    gral_usr_id_cancela integer DEFAULT 0,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0
);


ALTER TABLE gral_imptos_ret OWNER TO sumar;

--
-- Name: gral_imptos_ret_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_imptos_ret_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_imptos_ret_id_seq OWNER TO sumar;

--
-- Name: gral_imptos_ret_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_imptos_ret_id_seq OWNED BY gral_imptos_ret.id;


--
-- Name: gral_isr; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE gral_isr (
    id integer NOT NULL,
    titulo character varying DEFAULT ''::character varying NOT NULL,
    descripcion character varying NOT NULL,
    tasa double precision DEFAULT 0,
    borrado_logico boolean DEFAULT false NOT NULL,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_usr_id_crea integer DEFAULT 0,
    gral_usr_id_actualiza integer DEFAULT 0,
    gral_usr_id_cancela integer DEFAULT 0,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0
);


ALTER TABLE gral_isr OWNER TO sumar;

--
-- Name: gral_isr_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_isr_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_isr_id_seq OWNER TO sumar;

--
-- Name: gral_isr_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_isr_id_seq OWNED BY gral_isr.id;


--
-- Name: gral_mon; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: gral_mun; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: gral_pais; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: gral_plazas; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE gral_plazas (
    titulo character varying NOT NULL,
    descripcion character varying NOT NULL,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    borrado_logico boolean,
    id integer NOT NULL,
    empresa_id integer,
    inv_zonas_id integer,
    estatus boolean DEFAULT true
);


ALTER TABLE gral_plazas OWNER TO sumar;

--
-- Name: gral_plazas_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_plazas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_plazas_id_seq OWNER TO sumar;

--
-- Name: gral_plazas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_plazas_id_seq OWNED BY gral_plazas.id;


--
-- Name: gral_puestos; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: gral_reg; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE gral_reg (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    borrado_logico boolean
);


ALTER TABLE gral_reg OWNER TO sumar;

--
-- Name: gral_reg_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_reg_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_reg_id_seq OWNER TO sumar;

--
-- Name: gral_reg_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_reg_id_seq OWNED BY gral_reg.id;


--
-- Name: gral_religions; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: gral_sangretipos; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: gral_sexos; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: gral_suc; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: gral_suc_pza; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE gral_suc_pza (
    id integer NOT NULL,
    plaza_id integer NOT NULL,
    sucursal_id integer NOT NULL
);


ALTER TABLE gral_suc_pza OWNER TO sumar;

--
-- Name: gral_suc_pza_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE gral_suc_pza_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE gral_suc_pza_id_seq OWNER TO sumar;

--
-- Name: gral_suc_pza_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE gral_suc_pza_id_seq OWNED BY gral_suc_pza.id;


--
-- Name: gral_tc_url; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: gral_usr_suc; Type: TABLE; Schema: public; Owner: sumar
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
-- Name: inv_alm; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE inv_alm (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    borrado_logico boolean,
    calle character varying,
    colonia character varying,
    numero character varying,
    codigo_postal character varying,
    almacen_tipo_id integer,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_pais_id integer,
    gral_edo_id integer,
    gral_mun_id integer,
    reporteo boolean DEFAULT false,
    ventas boolean DEFAULT false,
    compras boolean DEFAULT false,
    reabastecimiento boolean DEFAULT false,
    garantias boolean DEFAULT false,
    consignacion boolean DEFAULT false,
    recepcion_mat boolean DEFAULT false,
    explosion_mat boolean DEFAULT false,
    responsable character varying,
    responsable_email character varying,
    responsable_puesto character varying,
    tel_1_ext character varying,
    tel_2_ext character varying,
    tel_2 character varying,
    tel_1 character varying,
    traspaso boolean DEFAULT false
);


ALTER TABLE inv_alm OWNER TO sumar;

--
-- Name: TABLE inv_alm; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON TABLE inv_alm IS 'Tabla que define los almacenes que seran compartidos por una o mas sucursales';


--
-- Name: inv_alm_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE inv_alm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inv_alm_id_seq OWNER TO sumar;

--
-- Name: inv_alm_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE inv_alm_id_seq OWNED BY inv_alm.id;


--
-- Name: inv_alm_tipos; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE inv_alm_tipos (
    id integer NOT NULL,
    titulo character varying NOT NULL
);


ALTER TABLE inv_alm_tipos OWNER TO sumar;

--
-- Name: TABLE inv_alm_tipos; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON TABLE inv_alm_tipos IS 'Alberga las diferentes clasificaciones que pudiece tener los almacenes del sistema';


--
-- Name: inv_alm_tipos_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE inv_alm_tipos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inv_alm_tipos_id_seq OWNER TO sumar;

--
-- Name: inv_alm_tipos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE inv_alm_tipos_id_seq OWNED BY inv_alm_tipos.id;


--
-- Name: inv_clas; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE inv_clas (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    stock_seguridad double precision,
    factor_maximo double precision,
    borrado_logico boolean DEFAULT false,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0,
    descripcion character varying DEFAULT ''::character varying
);


ALTER TABLE inv_clas OWNER TO sumar;

--
-- Name: inv_clas_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE inv_clas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inv_clas_id_seq OWNER TO sumar;

--
-- Name: inv_clas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE inv_clas_id_seq OWNED BY inv_clas.id;


--
-- Name: inv_exi; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE inv_exi (
    id integer NOT NULL,
    inv_prod_id integer NOT NULL,
    inv_alm_id integer NOT NULL,
    ano smallint NOT NULL,
    transito double precision DEFAULT 0 NOT NULL,
    reservado double precision DEFAULT 0,
    exi_inicial double precision DEFAULT 0 NOT NULL,
    entradas_1 double precision DEFAULT 0 NOT NULL,
    salidas_1 double precision DEFAULT 0 NOT NULL,
    costo_ultimo_1 double precision DEFAULT 0 NOT NULL,
    entradas_2 double precision DEFAULT 0 NOT NULL,
    salidas_2 double precision DEFAULT 0 NOT NULL,
    costo_ultimo_2 double precision DEFAULT 0 NOT NULL,
    entradas_3 double precision DEFAULT 0 NOT NULL,
    salidas_3 double precision DEFAULT 0 NOT NULL,
    costo_ultimo_3 double precision DEFAULT 0 NOT NULL,
    entradas_4 double precision DEFAULT 0 NOT NULL,
    salidas_4 double precision DEFAULT 0 NOT NULL,
    costo_ultimo_4 double precision DEFAULT 0 NOT NULL,
    entradas_5 double precision DEFAULT 0 NOT NULL,
    salidas_5 double precision DEFAULT 0 NOT NULL,
    costo_ultimo_5 double precision DEFAULT 0 NOT NULL,
    entradas_6 double precision DEFAULT 0 NOT NULL,
    salidas_6 double precision DEFAULT 0 NOT NULL,
    costo_ultimo_6 double precision DEFAULT 0 NOT NULL,
    entradas_7 double precision DEFAULT 0 NOT NULL,
    salidas_7 double precision DEFAULT 0 NOT NULL,
    costo_ultimo_7 double precision DEFAULT 0 NOT NULL,
    entradas_8 double precision DEFAULT 0 NOT NULL,
    salidas_8 double precision DEFAULT 0 NOT NULL,
    costo_ultimo_8 double precision DEFAULT 0 NOT NULL,
    entradas_9 double precision DEFAULT 0 NOT NULL,
    salidas_9 double precision DEFAULT 0 NOT NULL,
    costo_ultimo_9 double precision DEFAULT 0 NOT NULL,
    entradas_10 double precision DEFAULT 0 NOT NULL,
    salidas_10 double precision DEFAULT 0 NOT NULL,
    costo_ultimo_10 double precision DEFAULT 0 NOT NULL,
    entradas_11 double precision DEFAULT 0 NOT NULL,
    salidas_11 double precision DEFAULT 0 NOT NULL,
    costo_ultimo_11 double precision DEFAULT 0 NOT NULL,
    entradas_12 double precision DEFAULT 0 NOT NULL,
    salidas_12 double precision DEFAULT 0 NOT NULL,
    costo_ultimo_12 double precision DEFAULT 0 NOT NULL,
    momento_entrada_1 timestamp with time zone,
    momento_salida_1 timestamp with time zone,
    momento_entrada_2 timestamp with time zone,
    momento_salida_2 timestamp with time zone,
    momento_entrada_3 timestamp with time zone,
    momento_salida_3 timestamp with time zone,
    momento_entrada_4 timestamp with time zone,
    momento_salida_4 timestamp with time zone,
    momento_entrada_5 timestamp with time zone,
    momento_salida_5 timestamp with time zone,
    momento_entrada_6 timestamp with time zone,
    momento_salida_6 timestamp with time zone,
    momento_entrada_7 timestamp with time zone,
    momento_salida_7 timestamp with time zone,
    momento_entrada_8 timestamp with time zone,
    momento_salida_8 timestamp with time zone,
    momento_entrada_9 timestamp with time zone,
    momento_salida_9 timestamp with time zone,
    momento_entrada_10 timestamp with time zone,
    momento_salida_10 timestamp with time zone,
    momento_entrada_11 timestamp with time zone,
    momento_salida_11 timestamp with time zone,
    momento_entrada_12 timestamp with time zone,
    momento_salida_12 timestamp with time zone
);


ALTER TABLE inv_exi OWNER TO sumar;

--
-- Name: inv_exi_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE inv_exi_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inv_exi_id_seq OWNER TO sumar;

--
-- Name: inv_exi_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE inv_exi_id_seq OWNED BY inv_exi.id;


--
-- Name: inv_kit; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE inv_kit (
    id integer NOT NULL,
    producto_kit_id integer NOT NULL,
    cantidad double precision,
    producto_elemento_id integer
);


ALTER TABLE inv_kit OWNER TO sumar;

--
-- Name: inv_kit_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE inv_kit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inv_kit_id_seq OWNER TO sumar;

--
-- Name: inv_kit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE inv_kit_id_seq OWNED BY inv_kit.id;


--
-- Name: inv_mar; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE inv_mar (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    url character varying,
    estatus boolean DEFAULT true,
    borrado_logico boolean DEFAULT false,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0
);


ALTER TABLE inv_mar OWNER TO sumar;

--
-- Name: TABLE inv_mar; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON TABLE inv_mar IS 'Alberga todas las posibles marcas de productos que se pudieran manejar en el sistema';


--
-- Name: inv_mar_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE inv_mar_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inv_mar_id_seq OWNER TO sumar;

--
-- Name: inv_mar_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE inv_mar_id_seq OWNED BY inv_mar.id;


--
-- Name: inv_mov_tipos; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE inv_mov_tipos (
    id integer NOT NULL,
    titulo character varying,
    descripcion character varying,
    momento_creacion timestamp with time zone,
    momento_baja timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    borrado_logico boolean DEFAULT false,
    grupo smallint DEFAULT 0 NOT NULL,
    afecta_compras boolean DEFAULT false NOT NULL,
    afecta_ventas boolean DEFAULT false NOT NULL,
    considera_consumo boolean DEFAULT false NOT NULL,
    tipo_costo smallint,
    ajuste boolean DEFAULT false NOT NULL
);


ALTER TABLE inv_mov_tipos OWNER TO sumar;

--
-- Name: COLUMN inv_mov_tipos.grupo; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN inv_mov_tipos.grupo IS '0=Entradas, 1=Existencia Inicial, 2=Salidas, 3=Traspasos';


--
-- Name: COLUMN inv_mov_tipos.tipo_costo; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN inv_mov_tipos.tipo_costo IS '0=Alimentado, 1=Promedio, 2=Ultima Entrada';


--
-- Name: inv_mov_tipos_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE inv_mov_tipos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inv_mov_tipos_id_seq OWNER TO sumar;

--
-- Name: inv_mov_tipos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE inv_mov_tipos_id_seq OWNED BY inv_mov_tipos.id;


--
-- Name: inv_pre; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE inv_pre (
    id integer NOT NULL,
    inv_prod_id integer NOT NULL,
    precio_1 double precision,
    precio_2 double precision,
    precio_3 double precision,
    precio_4 double precision,
    precio_5 double precision,
    precio_6 double precision,
    precio_7 double precision,
    precio_8 double precision,
    precio_9 double precision,
    precio_10 double precision,
    descuento_1 double precision,
    descuento_2 double precision,
    descuento_3 double precision,
    descuento_4 double precision,
    descuento_5 double precision,
    descuento_6 double precision,
    descuento_7 double precision,
    descuento_8 double precision,
    descuento_9 double precision,
    descuento_10 double precision,
    base_precio_1 integer,
    base_precio_2 integer,
    base_precio_3 integer,
    base_precio_4 integer,
    base_precio_5 integer,
    base_precio_6 integer,
    base_precio_7 integer,
    base_precio_8 integer,
    base_precio_9 integer,
    base_precio_10 integer,
    default_precio_1 double precision,
    default_precio_2 double precision,
    default_precio_3 double precision,
    default_precio_4 double precision,
    default_precio_5 double precision,
    default_precio_6 double precision,
    default_precio_7 double precision,
    default_precio_8 double precision,
    default_precio_9 double precision,
    default_precio_10 double precision,
    operacion_precio_1 integer,
    operacion_precio_2 integer,
    operacion_precio_3 integer,
    operacion_precio_4 integer,
    operacion_precio_5 integer,
    operacion_precio_6 integer,
    operacion_precio_7 integer,
    operacion_precio_8 integer,
    operacion_precio_9 integer,
    operacion_precio_10 integer,
    calculo_precio_1 integer,
    calculo_precio_2 integer,
    calculo_precio_3 integer,
    calculo_precio_4 integer,
    calculo_precio_5 integer,
    calculo_precio_6 integer,
    calculo_precio_7 integer,
    calculo_precio_8 integer,
    calculo_precio_9 integer,
    calculo_precio_10 integer,
    redondeo_precio_1 integer,
    redondeo_precio_2 integer,
    redondeo_precio_3 integer,
    redondeo_precio_4 integer,
    redondeo_precio_5 integer,
    redondeo_precio_6 integer,
    redondeo_precio_7 integer,
    redondeo_precio_8 integer,
    redondeo_precio_9 integer,
    redondeo_precio_10 integer,
    gral_emp_id integer,
    borrado_logico boolean NOT NULL,
    momento_creacion timestamp with time zone NOT NULL,
    momento_baja timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0,
    gral_mon_id_pre1 integer DEFAULT 0 NOT NULL,
    gral_mon_id_pre2 integer DEFAULT 0 NOT NULL,
    gral_mon_id_pre3 integer DEFAULT 0 NOT NULL,
    gral_mon_id_pre4 integer DEFAULT 0 NOT NULL,
    gral_mon_id_pre5 integer DEFAULT 0 NOT NULL,
    gral_mon_id_pre6 integer DEFAULT 0 NOT NULL,
    gral_mon_id_pre7 integer DEFAULT 0 NOT NULL,
    gral_mon_id_pre8 integer DEFAULT 0 NOT NULL,
    gral_mon_id_pre9 integer DEFAULT 0 NOT NULL,
    gral_mon_id_pre10 integer DEFAULT 0 NOT NULL,
    inv_prod_presentacion_id integer DEFAULT 0
);


ALTER TABLE inv_pre OWNER TO sumar;

--
-- Name: inv_pre_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE inv_pre_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inv_pre_id_seq OWNER TO sumar;

--
-- Name: inv_pre_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE inv_pre_id_seq OWNED BY inv_pre.id;


--
-- Name: inv_prod; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE inv_prod (
    id integer NOT NULL,
    sku character varying DEFAULT ''::character varying,
    descripcion character varying NOT NULL,
    codigo_barras character varying DEFAULT ''::character varying,
    tentrega integer DEFAULT 0,
    inv_clas_id integer DEFAULT 0,
    inv_stock_clasif_id integer DEFAULT 0,
    estatus boolean DEFAULT true,
    inv_prod_familia_id integer DEFAULT 0,
    subfamilia_id integer DEFAULT 0,
    inv_prod_grupo_id integer DEFAULT 0,
    ieps integer DEFAULT 0,
    meta_impuesto character varying DEFAULT ''::character varying,
    inv_prod_linea_id integer DEFAULT 0,
    inv_mar_id integer DEFAULT 0,
    tipo_de_producto_id integer DEFAULT 0,
    inv_seccion_id integer DEFAULT 0,
    unidad_id integer DEFAULT 0,
    requiere_numero_serie boolean DEFAULT false,
    requiere_numero_lote boolean DEFAULT false,
    requiere_pedimento boolean DEFAULT false,
    permitir_stock boolean DEFAULT false,
    venta_moneda_extranjera boolean DEFAULT false,
    compra_moneda_extranjera boolean DEFAULT false,
    requiere_nom boolean DEFAULT false,
    borrado_logico boolean DEFAULT false NOT NULL,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    id_usuario_creacion integer DEFAULT 0,
    id_usuario_actualizacion integer DEFAULT 0,
    id_usuario_baja integer DEFAULT 0,
    sucursal_id integer DEFAULT 0,
    empresa_id integer DEFAULT 0,
    cxp_prov_id integer DEFAULT 0,
    sku_aux character varying DEFAULT ''::character varying,
    id_aux integer DEFAULT 0,
    densidad double precision DEFAULT 0,
    valor_maximo double precision DEFAULT 0,
    valor_minimo double precision DEFAULT 0,
    punto_reorden double precision DEFAULT 0,
    gral_impto_id integer DEFAULT 0,
    ctb_cta_id_gasto integer DEFAULT 0,
    ctb_cta_id_costo_venta integer DEFAULT 0,
    ctb_cta_id_venta integer DEFAULT 0,
    descripcion_corta text,
    descripcion_larga text,
    archivo_img character varying DEFAULT ''::character varying,
    archivo_pdf character varying DEFAULT ''::character varying,
    inv_prod_presentacion_id integer DEFAULT 0,
    flete boolean DEFAULT false NOT NULL,
    no_clie character varying DEFAULT ''::character varying NOT NULL,
    gral_mon_id integer DEFAULT 0 NOT NULL,
    gral_imptos_ret_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE inv_prod OWNER TO sumar;

--
-- Name: COLUMN inv_prod.gral_impto_id; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN inv_prod.gral_impto_id IS 'Impuesto especifico para el Producto';


--
-- Name: COLUMN inv_prod.ctb_cta_id_gasto; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN inv_prod.ctb_cta_id_gasto IS 'id de la Cuenta Contable para Gastos';


--
-- Name: COLUMN inv_prod.ctb_cta_id_costo_venta; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN inv_prod.ctb_cta_id_costo_venta IS 'id de la Cuenta Contable para Costo de Venta';


--
-- Name: COLUMN inv_prod.ctb_cta_id_venta; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN inv_prod.ctb_cta_id_venta IS 'id de la Cuenta Contable para Ventas';


--
-- Name: COLUMN inv_prod.inv_prod_presentacion_id; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN inv_prod.inv_prod_presentacion_id IS 'Id de la Presentacion DEFAULT. Esta presentacion debera ser Equivalente a la Unidad de Medida del Producto.';


--
-- Name: COLUMN inv_prod.flete; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN inv_prod.flete IS 'Indica que el producto es un flete y debe retener impuesto cuando la empresa sea transportista.';


--
-- Name: inv_prod_cost_prom; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE inv_prod_cost_prom (
    id integer NOT NULL,
    inv_prod_id integer NOT NULL,
    ano smallint NOT NULL,
    costo_promedio_1 double precision DEFAULT 0 NOT NULL,
    costo_promedio_2 double precision DEFAULT 0 NOT NULL,
    costo_promedio_3 double precision DEFAULT 0 NOT NULL,
    costo_promedio_4 double precision DEFAULT 0 NOT NULL,
    costo_promedio_5 double precision DEFAULT 0 NOT NULL,
    costo_promedio_6 double precision DEFAULT 0 NOT NULL,
    costo_promedio_7 double precision DEFAULT 0 NOT NULL,
    costo_promedio_8 double precision DEFAULT 0 NOT NULL,
    costo_promedio_9 double precision DEFAULT 0 NOT NULL,
    costo_promedio_10 double precision DEFAULT 0 NOT NULL,
    costo_promedio_11 double precision DEFAULT 0 NOT NULL,
    costo_promedio_12 double precision DEFAULT 0 NOT NULL,
    costo_ultimo_1 double precision DEFAULT 0 NOT NULL,
    tipo_cambio_1 double precision DEFAULT 0 NOT NULL,
    gral_mon_id_1 smallint DEFAULT 0 NOT NULL,
    costo_ultimo_2 double precision DEFAULT 0 NOT NULL,
    tipo_cambio_2 double precision DEFAULT 0 NOT NULL,
    gral_mon_id_2 smallint DEFAULT 0 NOT NULL,
    costo_ultimo_3 double precision DEFAULT 0 NOT NULL,
    tipo_cambio_3 double precision DEFAULT 0 NOT NULL,
    gral_mon_id_3 smallint DEFAULT 0 NOT NULL,
    costo_ultimo_4 double precision DEFAULT 0 NOT NULL,
    tipo_cambio_4 double precision DEFAULT 0 NOT NULL,
    gral_mon_id_4 smallint DEFAULT 0 NOT NULL,
    costo_ultimo_5 double precision DEFAULT 0 NOT NULL,
    tipo_cambio_5 double precision DEFAULT 0 NOT NULL,
    gral_mon_id_5 smallint DEFAULT 0 NOT NULL,
    costo_ultimo_6 double precision DEFAULT 0 NOT NULL,
    tipo_cambio_6 double precision DEFAULT 0 NOT NULL,
    gral_mon_id_6 smallint DEFAULT 0 NOT NULL,
    costo_ultimo_7 double precision DEFAULT 0 NOT NULL,
    tipo_cambio_7 double precision DEFAULT 0 NOT NULL,
    gral_mon_id_7 smallint DEFAULT 0 NOT NULL,
    costo_ultimo_8 double precision DEFAULT 0 NOT NULL,
    tipo_cambio_8 double precision DEFAULT 0 NOT NULL,
    gral_mon_id_8 smallint DEFAULT 0 NOT NULL,
    costo_ultimo_9 double precision DEFAULT 0 NOT NULL,
    tipo_cambio_9 double precision DEFAULT 0 NOT NULL,
    gral_mon_id_9 smallint DEFAULT 0 NOT NULL,
    costo_ultimo_10 double precision DEFAULT 0 NOT NULL,
    tipo_cambio_10 double precision DEFAULT 0 NOT NULL,
    gral_mon_id_10 smallint DEFAULT 0 NOT NULL,
    costo_ultimo_11 double precision DEFAULT 0 NOT NULL,
    tipo_cambio_11 double precision DEFAULT 0 NOT NULL,
    gral_mon_id_11 smallint DEFAULT 0 NOT NULL,
    costo_ultimo_12 double precision DEFAULT 0 NOT NULL,
    tipo_cambio_12 double precision DEFAULT 0 NOT NULL,
    gral_mon_id_12 smallint DEFAULT 0 NOT NULL,
    actualizacion_1 timestamp with time zone,
    actualizacion_2 timestamp with time zone,
    actualizacion_3 timestamp with time zone,
    actualizacion_4 timestamp with time zone,
    actualizacion_5 timestamp with time zone,
    actualizacion_6 timestamp with time zone,
    actualizacion_7 timestamp with time zone,
    actualizacion_8 timestamp with time zone,
    actualizacion_9 timestamp with time zone,
    actualizacion_10 timestamp with time zone,
    actualizacion_11 timestamp with time zone,
    actualizacion_12 timestamp with time zone,
    factura_ultima_1 character varying DEFAULT ''::character varying,
    oc_ultima_1 character varying DEFAULT ''::character varying,
    factura_ultima_2 character varying DEFAULT ''::character varying,
    oc_ultima_2 character varying DEFAULT ''::character varying,
    factura_ultima_3 character varying DEFAULT ''::character varying,
    oc_ultima_3 character varying DEFAULT ''::character varying,
    factura_ultima_4 character varying DEFAULT ''::character varying,
    oc_ultima_4 character varying DEFAULT ''::character varying,
    factura_ultima_5 character varying DEFAULT ''::character varying,
    oc_ultima_5 character varying DEFAULT ''::character varying,
    factura_ultima_6 character varying DEFAULT ''::character varying,
    oc_ultima_6 character varying DEFAULT ''::character varying,
    factura_ultima_7 character varying DEFAULT ''::character varying,
    oc_ultima_7 character varying DEFAULT ''::character varying,
    factura_ultima_8 character varying DEFAULT ''::character varying,
    oc_ultima_8 character varying DEFAULT ''::character varying,
    factura_ultima_9 character varying DEFAULT ''::character varying,
    oc_ultima_9 character varying DEFAULT ''::character varying,
    factura_ultima_10 character varying DEFAULT ''::character varying,
    oc_ultima_10 character varying DEFAULT ''::character varying,
    factura_ultima_11 character varying DEFAULT ''::character varying,
    oc_ultima_11 character varying DEFAULT ''::character varying,
    factura_ultima_12 character varying DEFAULT ''::character varying,
    oc_ultima_12 character varying DEFAULT ''::character varying
);


ALTER TABLE inv_prod_cost_prom OWNER TO sumar;

--
-- Name: inv_prod_cost_prom_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE inv_prod_cost_prom_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inv_prod_cost_prom_id_seq OWNER TO sumar;

--
-- Name: inv_prod_cost_prom_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE inv_prod_cost_prom_id_seq OWNED BY inv_prod_cost_prom.id;


--
-- Name: inv_prod_familias; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE inv_prod_familias (
    id integer NOT NULL,
    identificador_familia_padre integer,
    titulo character varying NOT NULL,
    descripcion text NOT NULL,
    borrado_logico boolean DEFAULT false NOT NULL,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0,
    inv_prod_tipo_id integer DEFAULT 0
);


ALTER TABLE inv_prod_familias OWNER TO sumar;

--
-- Name: inv_prod_familias_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE inv_prod_familias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inv_prod_familias_id_seq OWNER TO sumar;

--
-- Name: inv_prod_familias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE inv_prod_familias_id_seq OWNED BY inv_prod_familias.id;


--
-- Name: inv_prod_grupos; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE inv_prod_grupos (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    descripcion text NOT NULL,
    borrado_logico boolean DEFAULT false NOT NULL,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0
);


ALTER TABLE inv_prod_grupos OWNER TO sumar;

--
-- Name: inv_prod_grupos_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE inv_prod_grupos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inv_prod_grupos_id_seq OWNER TO sumar;

--
-- Name: inv_prod_grupos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE inv_prod_grupos_id_seq OWNED BY inv_prod_grupos.id;


--
-- Name: inv_prod_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE inv_prod_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inv_prod_id_seq OWNER TO sumar;

--
-- Name: inv_prod_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE inv_prod_id_seq OWNED BY inv_prod.id;


--
-- Name: inv_prod_lineas; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE inv_prod_lineas (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    descripcion text NOT NULL,
    inv_seccion_id integer,
    borrado_logico boolean DEFAULT false NOT NULL,
    momento_actualizacion timestamp with time zone,
    momento_creacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0
);


ALTER TABLE inv_prod_lineas OWNER TO sumar;

--
-- Name: inv_prod_lineas_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE inv_prod_lineas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inv_prod_lineas_id_seq OWNER TO sumar;

--
-- Name: inv_prod_lineas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE inv_prod_lineas_id_seq OWNED BY inv_prod_lineas.id;


--
-- Name: inv_prod_pres_x_prod; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE inv_prod_pres_x_prod (
    id integer NOT NULL,
    producto_id integer,
    presentacion_id integer,
    producto_id_aux integer
);


ALTER TABLE inv_prod_pres_x_prod OWNER TO sumar;

--
-- Name: inv_prod_pres_x_prod_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE inv_prod_pres_x_prod_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inv_prod_pres_x_prod_id_seq OWNER TO sumar;

--
-- Name: inv_prod_pres_x_prod_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE inv_prod_pres_x_prod_id_seq OWNED BY inv_prod_pres_x_prod.id;


--
-- Name: inv_prod_presentaciones; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE inv_prod_presentaciones (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    borrado_logico boolean DEFAULT false,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0,
    cantidad double precision DEFAULT 0
);


ALTER TABLE inv_prod_presentaciones OWNER TO sumar;

--
-- Name: COLUMN inv_prod_presentaciones.cantidad; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN inv_prod_presentaciones.cantidad IS 'Equivalencia de la presentacion en Cantidad de acuerdo a la Unidad de Medida definida.';


--
-- Name: inv_prod_presentaciones_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE inv_prod_presentaciones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inv_prod_presentaciones_id_seq OWNER TO sumar;

--
-- Name: inv_prod_presentaciones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE inv_prod_presentaciones_id_seq OWNED BY inv_prod_presentaciones.id;


--
-- Name: inv_prod_tipos; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE inv_prod_tipos (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    borrado_logico boolean DEFAULT false
);


ALTER TABLE inv_prod_tipos OWNER TO sumar;

--
-- Name: TABLE inv_prod_tipos; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON TABLE inv_prod_tipos IS 'Alberga las diferentes clasificaciones que pudiece tener los productos  del sistema';


--
-- Name: inv_prod_tipos_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE inv_prod_tipos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inv_prod_tipos_id_seq OWNER TO sumar;

--
-- Name: inv_prod_tipos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE inv_prod_tipos_id_seq OWNED BY inv_prod_tipos.id;


--
-- Name: inv_prod_unidades; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE inv_prod_unidades (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    borrado_logico boolean DEFAULT false NOT NULL,
    titulo_abr character varying DEFAULT ''::character varying,
    decimales integer
);


ALTER TABLE inv_prod_unidades OWNER TO sumar;

--
-- Name: TABLE inv_prod_unidades; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON TABLE inv_prod_unidades IS 'Alberga las unidades de medida de productos que podra manipular el sistema';


--
-- Name: inv_prod_unidades_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE inv_prod_unidades_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inv_prod_unidades_id_seq OWNER TO sumar;

--
-- Name: inv_prod_unidades_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE inv_prod_unidades_id_seq OWNED BY inv_prod_unidades.id;


--
-- Name: inv_secciones; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE inv_secciones (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    borrado_logico boolean,
    activa boolean,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    descripcion character varying,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0
);


ALTER TABLE inv_secciones OWNER TO sumar;

--
-- Name: inv_secciones_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE inv_secciones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inv_secciones_id_seq OWNER TO sumar;

--
-- Name: inv_secciones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE inv_secciones_id_seq OWNED BY inv_secciones.id;


--
-- Name: inv_stock_clasificaciones; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE inv_stock_clasificaciones (
    id integer NOT NULL,
    titulo character varying,
    descripcion character varying,
    borrado_logico boolean DEFAULT false NOT NULL,
    momento_creacion timestamp without time zone,
    momento_actualizacion timestamp without time zone,
    momento_baja timestamp without time zone,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0
);


ALTER TABLE inv_stock_clasificaciones OWNER TO sumar;

--
-- Name: inv_stock_clasificaciones_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE inv_stock_clasificaciones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inv_stock_clasificaciones_id_seq OWNER TO sumar;

--
-- Name: inv_stock_clasificaciones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE inv_stock_clasificaciones_id_seq OWNED BY inv_stock_clasificaciones.id;


--
-- Name: inv_suc_alm; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE inv_suc_alm (
    id integer NOT NULL,
    almacen_id integer NOT NULL,
    sucursal_id integer NOT NULL
);


ALTER TABLE inv_suc_alm OWNER TO sumar;

--
-- Name: inv_suc_alm_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE inv_suc_alm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE inv_suc_alm_id_seq OWNER TO sumar;

--
-- Name: inv_suc_alm_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE inv_suc_alm_id_seq OWNED BY inv_suc_alm.id;


--
-- Name: nom_deduc; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE nom_deduc (
    id integer NOT NULL,
    clave character varying DEFAULT ''::character varying NOT NULL,
    titulo character varying DEFAULT ''::character varying NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    nom_deduc_tipo_id integer DEFAULT 0,
    borrado_logico boolean DEFAULT false NOT NULL,
    momento_creacion timestamp with time zone,
    momento_actualiza timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_usr_id_crea integer DEFAULT 0,
    gral_usr_id_actualiza integer DEFAULT 0,
    gral_usr_id_cancela integer DEFAULT 0,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0
);


ALTER TABLE nom_deduc OWNER TO sumar;

--
-- Name: nom_deduc_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE nom_deduc_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE nom_deduc_id_seq OWNER TO sumar;

--
-- Name: nom_deduc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE nom_deduc_id_seq OWNED BY nom_deduc.id;


--
-- Name: nom_deduc_tipo; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE nom_deduc_tipo (
    id integer NOT NULL,
    clave character varying DEFAULT ''::character varying NOT NULL,
    titulo character varying DEFAULT ''::character varying NOT NULL,
    activo boolean DEFAULT true NOT NULL
);


ALTER TABLE nom_deduc_tipo OWNER TO sumar;

--
-- Name: nom_deduc_tipo_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE nom_deduc_tipo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE nom_deduc_tipo_id_seq OWNER TO sumar;

--
-- Name: nom_deduc_tipo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE nom_deduc_tipo_id_seq OWNED BY nom_deduc_tipo.id;


--
-- Name: nom_percep; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE nom_percep (
    id integer NOT NULL,
    clave character varying DEFAULT ''::character varying NOT NULL,
    titulo character varying DEFAULT ''::character varying NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    nom_percep_tipo_id integer DEFAULT 0,
    borrado_logico boolean DEFAULT false NOT NULL,
    momento_creacion timestamp with time zone,
    momento_actualiza timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_usr_id_crea integer DEFAULT 0,
    gral_usr_id_actualiza integer DEFAULT 0,
    gral_usr_id_cancela integer DEFAULT 0,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0
);


ALTER TABLE nom_percep OWNER TO sumar;

--
-- Name: nom_percep_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE nom_percep_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE nom_percep_id_seq OWNER TO sumar;

--
-- Name: nom_percep_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE nom_percep_id_seq OWNED BY nom_percep.id;


--
-- Name: nom_percep_tipo; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE nom_percep_tipo (
    id integer NOT NULL,
    clave character varying DEFAULT ''::character varying NOT NULL,
    titulo character varying DEFAULT ''::character varying NOT NULL,
    activo boolean DEFAULT true NOT NULL
);


ALTER TABLE nom_percep_tipo OWNER TO sumar;

--
-- Name: nom_percep_tipo_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE nom_percep_tipo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE nom_percep_tipo_id_seq OWNER TO sumar;

--
-- Name: nom_percep_tipo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE nom_percep_tipo_id_seq OWNED BY nom_percep_tipo.id;


--
-- Name: nom_periodicidad_pago; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE nom_periodicidad_pago (
    id integer NOT NULL,
    titulo character varying DEFAULT ''::character varying NOT NULL,
    no_periodos integer DEFAULT 0,
    activo boolean DEFAULT true NOT NULL,
    borrado_logico boolean DEFAULT false,
    momento_creacion timestamp with time zone,
    momento_actualiza timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_usr_id_crea integer DEFAULT 0,
    gral_usr_id_actualiza integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0
);


ALTER TABLE nom_periodicidad_pago OWNER TO sumar;

--
-- Name: nom_periodicidad_pago_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE nom_periodicidad_pago_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE nom_periodicidad_pago_id_seq OWNER TO sumar;

--
-- Name: nom_periodicidad_pago_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE nom_periodicidad_pago_id_seq OWNED BY nom_periodicidad_pago.id;


--
-- Name: nom_periodos_conf; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE nom_periodos_conf (
    id integer NOT NULL,
    ano integer DEFAULT 0 NOT NULL,
    nom_periodicidad_pago_id integer,
    prefijo character varying DEFAULT ''::character varying,
    borrado_logico boolean DEFAULT false,
    momento_creacion timestamp with time zone,
    momento_actualiza timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_usr_id_crea integer DEFAULT 0,
    gral_usr_id_actualiza integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0
);


ALTER TABLE nom_periodos_conf OWNER TO sumar;

--
-- Name: nom_periodos_conf_det; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE nom_periodos_conf_det (
    id integer NOT NULL,
    nom_periodos_conf_id integer NOT NULL,
    folio character varying DEFAULT ''::character varying,
    titulo character varying DEFAULT ''::character varying NOT NULL,
    fecha_ini date,
    fecha_fin date,
    estatus boolean DEFAULT false
);


ALTER TABLE nom_periodos_conf_det OWNER TO sumar;

--
-- Name: nom_periodos_conf_det_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE nom_periodos_conf_det_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE nom_periodos_conf_det_id_seq OWNER TO sumar;

--
-- Name: nom_periodos_conf_det_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE nom_periodos_conf_det_id_seq OWNED BY nom_periodos_conf_det.id;


--
-- Name: nom_periodos_conf_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE nom_periodos_conf_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE nom_periodos_conf_id_seq OWNER TO sumar;

--
-- Name: nom_periodos_conf_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE nom_periodos_conf_id_seq OWNED BY nom_periodos_conf.id;


--
-- Name: nom_regimen_contratacion; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE nom_regimen_contratacion (
    id integer NOT NULL,
    clave character varying DEFAULT ''::character varying NOT NULL,
    titulo character varying DEFAULT ''::character varying NOT NULL,
    activo boolean DEFAULT true NOT NULL
);


ALTER TABLE nom_regimen_contratacion OWNER TO sumar;

--
-- Name: nom_regimen_contratacion_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE nom_regimen_contratacion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE nom_regimen_contratacion_id_seq OWNER TO sumar;

--
-- Name: nom_regimen_contratacion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE nom_regimen_contratacion_id_seq OWNED BY nom_regimen_contratacion.id;


--
-- Name: nom_riesgo_puesto; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE nom_riesgo_puesto (
    id integer NOT NULL,
    clave character varying DEFAULT ''::character varying NOT NULL,
    titulo character varying DEFAULT ''::character varying NOT NULL,
    activo boolean DEFAULT true NOT NULL
);


ALTER TABLE nom_riesgo_puesto OWNER TO sumar;

--
-- Name: nom_riesgo_puesto_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE nom_riesgo_puesto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE nom_riesgo_puesto_id_seq OWNER TO sumar;

--
-- Name: nom_riesgo_puesto_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE nom_riesgo_puesto_id_seq OWNED BY nom_riesgo_puesto.id;


--
-- Name: nom_tipo_contrato; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE nom_tipo_contrato (
    id integer NOT NULL,
    titulo character varying DEFAULT ''::character varying NOT NULL,
    activo boolean DEFAULT true NOT NULL
);


ALTER TABLE nom_tipo_contrato OWNER TO sumar;

--
-- Name: nom_tipo_contrato_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE nom_tipo_contrato_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE nom_tipo_contrato_id_seq OWNER TO sumar;

--
-- Name: nom_tipo_contrato_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE nom_tipo_contrato_id_seq OWNED BY nom_tipo_contrato.id;


--
-- Name: nom_tipo_hrs_extra; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE nom_tipo_hrs_extra (
    id integer NOT NULL,
    titulo character varying DEFAULT ''::character varying NOT NULL,
    activo boolean DEFAULT true NOT NULL
);


ALTER TABLE nom_tipo_hrs_extra OWNER TO sumar;

--
-- Name: nom_tipo_hrs_extra_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE nom_tipo_hrs_extra_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE nom_tipo_hrs_extra_id_seq OWNER TO sumar;

--
-- Name: nom_tipo_hrs_extra_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE nom_tipo_hrs_extra_id_seq OWNED BY nom_tipo_hrs_extra.id;


--
-- Name: nom_tipo_incapacidad; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE nom_tipo_incapacidad (
    id integer NOT NULL,
    clave character varying DEFAULT ''::character varying NOT NULL,
    titulo character varying DEFAULT ''::character varying NOT NULL,
    activo boolean DEFAULT true NOT NULL
);


ALTER TABLE nom_tipo_incapacidad OWNER TO sumar;

--
-- Name: nom_tipo_incapacidad_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE nom_tipo_incapacidad_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE nom_tipo_incapacidad_id_seq OWNER TO sumar;

--
-- Name: nom_tipo_incapacidad_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE nom_tipo_incapacidad_id_seq OWNED BY nom_tipo_incapacidad.id;


--
-- Name: nom_tipo_jornada; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE nom_tipo_jornada (
    id integer NOT NULL,
    titulo character varying DEFAULT ''::character varying NOT NULL,
    activo boolean DEFAULT true NOT NULL
);


ALTER TABLE nom_tipo_jornada OWNER TO sumar;

--
-- Name: nom_tipo_jornada_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE nom_tipo_jornada_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE nom_tipo_jornada_id_seq OWNER TO sumar;

--
-- Name: nom_tipo_jornada_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE nom_tipo_jornada_id_seq OWNED BY nom_tipo_jornada.id;


--
-- Name: poc_pedidos; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE poc_pedidos (
    id integer NOT NULL,
    folio character varying DEFAULT ''::character varying,
    cxc_clie_id integer NOT NULL,
    moneda_id integer,
    observaciones text,
    subtotal double precision,
    impuesto double precision,
    monto_retencion double precision DEFAULT 0,
    total double precision,
    tasa_retencion_immex double precision DEFAULT 0,
    tipo_cambio double precision DEFAULT 0,
    cxc_agen_id integer DEFAULT 0,
    cxp_prov_credias_id integer DEFAULT 0,
    orden_compra character varying DEFAULT ''::character varying,
    proceso_id integer NOT NULL,
    fecha_compromiso date,
    lugar_entrega character varying DEFAULT ''::character varying,
    transporte character varying DEFAULT ''::character varying,
    cancelado boolean DEFAULT false,
    borrado_logico boolean DEFAULT false,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_cancelacion timestamp with time zone,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_cancelacion integer DEFAULT 0,
    tipo_documento integer DEFAULT 0,
    gral_usr_id_autoriza integer DEFAULT 0,
    momento_autorizacion timestamp with time zone,
    fac_metodos_pago_id integer DEFAULT 0,
    no_cuenta character varying DEFAULT ''::character varying,
    enviar_ruta boolean DEFAULT false,
    inv_alm_id smallint DEFAULT 0,
    cxc_clie_df_id integer DEFAULT 0,
    enviar_obser_fac boolean DEFAULT false,
    flete boolean DEFAULT false NOT NULL,
    monto_ieps double precision DEFAULT 0,
    monto_descto double precision DEFAULT 0 NOT NULL,
    motivo_descto character varying DEFAULT ''::character varying,
    porcentaje_descto double precision DEFAULT 0,
    folio_cot character varying DEFAULT ''::character varying
);


ALTER TABLE poc_pedidos OWNER TO sumar;

--
-- Name: COLUMN poc_pedidos.enviar_ruta; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN poc_pedidos.enviar_ruta IS 'True=Despues de facturar el pedido debe aparecer en la busqueda de facturas para agregar a la ruta. False=No debe aparecer en la busqueda.';


--
-- Name: COLUMN poc_pedidos.inv_alm_id; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN poc_pedidos.inv_alm_id IS 'Almacen de donde se toma los productos y se reserva para el pedido';


--
-- Name: COLUMN poc_pedidos.cxc_clie_df_id; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN poc_pedidos.cxc_clie_df_id IS 'ID de la Direccion Fiscal(cxc_clie_df) para la Facturacion del Pedido. Si el valor de este campo es 0, entonces por default toma la direccion de la tabla de Clientes (cxc_clie)';


--
-- Name: COLUMN poc_pedidos.enviar_obser_fac; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN poc_pedidos.enviar_obser_fac IS 'TRUE=Indica que las observaciones capturadas en el pedido se enviaran a la Facturacion';


--
-- Name: poc_pedidos_detalle; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE poc_pedidos_detalle (
    id integer NOT NULL,
    poc_pedido_id integer,
    inv_prod_id integer NOT NULL,
    presentacion_id integer NOT NULL,
    cantidad double precision,
    precio_unitario double precision,
    gral_imp_id integer DEFAULT 0,
    valor_imp double precision DEFAULT 0,
    facturado boolean DEFAULT false,
    reservado double precision DEFAULT 0,
    backorder boolean DEFAULT false,
    inv_prod_unidad_id integer DEFAULT 0 NOT NULL,
    gral_ieps_id integer DEFAULT 0,
    valor_ieps double precision DEFAULT 0,
    descto double precision DEFAULT 0,
    requisicion boolean DEFAULT false,
    requiere_aut boolean DEFAULT false NOT NULL,
    autorizado boolean DEFAULT false NOT NULL,
    precio_aut double precision DEFAULT 0 NOT NULL,
    gral_usr_id_aut integer DEFAULT 0 NOT NULL,
    gral_imptos_ret_id integer DEFAULT 0 NOT NULL,
    tasa_ret double precision DEFAULT 0 NOT NULL
);


ALTER TABLE poc_pedidos_detalle OWNER TO sumar;

--
-- Name: COLUMN poc_pedidos_detalle.reservado; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN poc_pedidos_detalle.reservado IS 'Almacena la cantidad que reservó en inv_exi';


--
-- Name: COLUMN poc_pedidos_detalle.backorder; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN poc_pedidos_detalle.backorder IS 'TRUE=Generó BackOrder, FALSE=No generó BackOrder';


--
-- Name: COLUMN poc_pedidos_detalle.inv_prod_unidad_id; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN poc_pedidos_detalle.inv_prod_unidad_id IS 'Id de la unidad de medida de venta, puede ser diferente a la unidad de medida en el catalogo de productos.';


--
-- Name: COLUMN poc_pedidos_detalle.requisicion; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN poc_pedidos_detalle.requisicion IS 'TRUE=Indica si genero una orden de requision de compra';


--
-- Name: poc_pedidos_detalle_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE poc_pedidos_detalle_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE poc_pedidos_detalle_id_seq OWNER TO sumar;

--
-- Name: poc_pedidos_detalle_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE poc_pedidos_detalle_id_seq OWNED BY poc_pedidos_detalle.id;


--
-- Name: poc_pedidos_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE poc_pedidos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE poc_pedidos_id_seq OWNER TO sumar;

--
-- Name: poc_pedidos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE poc_pedidos_id_seq OWNED BY poc_pedidos.id;


--
-- Name: tes_ban; Type: TABLE; Schema: public; Owner: sumar
--

CREATE TABLE tes_ban (
    id integer NOT NULL,
    titulo character varying NOT NULL,
    descripcion character varying NOT NULL,
    borrado_logico boolean DEFAULT false,
    momento_creacion timestamp with time zone,
    momento_actualizacion timestamp with time zone,
    momento_baja timestamp with time zone,
    gral_emp_id integer DEFAULT 0,
    gral_suc_id integer DEFAULT 0,
    gral_usr_id_creacion integer DEFAULT 0,
    gral_usr_id_actualizacion integer DEFAULT 0,
    gral_usr_id_baja integer DEFAULT 0,
    clave character varying DEFAULT ''::character varying
);


ALTER TABLE tes_ban OWNER TO sumar;

--
-- Name: COLUMN tes_ban.clave; Type: COMMENT; Schema: public; Owner: sumar
--

COMMENT ON COLUMN tes_ban.clave IS 'Clave del catalogo de bancos del SAT';


--
-- Name: tes_ban_id_seq; Type: SEQUENCE; Schema: public; Owner: sumar
--

CREATE SEQUENCE tes_ban_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE tes_ban_id_seq OWNER TO sumar;

--
-- Name: tes_ban_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: sumar
--

ALTER SEQUENCE tes_ban_id_seq OWNED BY tes_ban.id;


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

ALTER TABLE ONLY ctb_may_clases ALTER COLUMN id SET DEFAULT nextval('ctb_may_clases_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie ALTER COLUMN id SET DEFAULT nextval('cxc_clie_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_clas1 ALTER COLUMN id SET DEFAULT nextval('cxc_clie_clas1_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_clas2 ALTER COLUMN id SET DEFAULT nextval('cxc_clie_clas2_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_clas3 ALTER COLUMN id SET DEFAULT nextval('cxc_clie_clas3_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_clases ALTER COLUMN id SET DEFAULT nextval('cxc_clie_clases_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_creapar ALTER COLUMN id SET DEFAULT nextval('cxc_clie_creapar_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_credias ALTER COLUMN id SET DEFAULT nextval('cxc_clie_credias_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_descto ALTER COLUMN id SET DEFAULT nextval('cxc_clie_descto_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_df ALTER COLUMN id SET DEFAULT nextval('cxc_clie_df_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_grupos ALTER COLUMN id SET DEFAULT nextval('cxc_clie_grupos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_zonas ALTER COLUMN id SET DEFAULT nextval('cxc_clie_zonas_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov ALTER COLUMN id SET DEFAULT nextval('cxp_prov_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_clas1 ALTER COLUMN id SET DEFAULT nextval('cxp_prov_clas1_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_clas2 ALTER COLUMN id SET DEFAULT nextval('cxp_prov_clas2_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_clas3 ALTER COLUMN id SET DEFAULT nextval('cxp_prov_clas3_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_clases ALTER COLUMN id SET DEFAULT nextval('cxp_prov_clases_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_contactos ALTER COLUMN id SET DEFAULT nextval('cxp_prov_contactos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_creapar ALTER COLUMN id SET DEFAULT nextval('cxp_prov_creapar_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_credias ALTER COLUMN id SET DEFAULT nextval('cxp_prov_credias_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_fleteras ALTER COLUMN id SET DEFAULT nextval('cxp_prov_fleteras_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_grupos ALTER COLUMN id SET DEFAULT nextval('cxp_prov_grupos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_tipos_embarque ALTER COLUMN id SET DEFAULT nextval('cxp_prov_tipos_embarque_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_zonas ALTER COLUMN id SET DEFAULT nextval('cxp_prov_zonas_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_clients_consignacions ALTER COLUMN id SET DEFAULT nextval('erp_clients_consignacions_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_h_facturas ALTER COLUMN id SET DEFAULT nextval('erp_h_facturas_id_seq'::regclass);


--
-- Name: app_id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_mascaras_para_validaciones_por_app ALTER COLUMN app_id SET DEFAULT nextval('erp_mascaras_para_validaciones_por_app_app_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_monedavers ALTER COLUMN id SET DEFAULT nextval('erp_monedavers_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_pagos_formas ALTER COLUMN id SET DEFAULT nextval('erp_pagos_formas_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_parametros_generales ALTER COLUMN id SET DEFAULT nextval('erp_parametros_generales_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_prefacturas ALTER COLUMN id SET DEFAULT nextval('erp_prefacturas_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_prefacturas_detalles ALTER COLUMN id SET DEFAULT nextval('erp_prefacturas_detalles_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_proceso ALTER COLUMN id SET DEFAULT nextval('erp_proceso_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_proceso_flujo ALTER COLUMN id SET DEFAULT nextval('erp_proceso_flujo_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_tiempos_entrega ALTER COLUMN id SET DEFAULT nextval('erp_tiempos_entrega_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_cfds_conf ALTER COLUMN id SET DEFAULT nextval('fac_cfds_conf_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_metodos_pago ALTER COLUMN id SET DEFAULT nextval('fac_metodos_pago_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_namespaces ALTER COLUMN id SET DEFAULT nextval('fac_namespaces_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_nomina ALTER COLUMN id SET DEFAULT nextval('fac_nomina_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_nomina_det ALTER COLUMN id SET DEFAULT nextval('fac_nomina_det_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_nomina_det_deduc ALTER COLUMN id SET DEFAULT nextval('fac_nomina_det_deduc_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_nomina_det_hrs_extra ALTER COLUMN id SET DEFAULT nextval('fac_nomina_det_hrs_extra_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_nomina_det_incapa ALTER COLUMN id SET DEFAULT nextval('fac_nomina_det_incapa_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_nomina_det_percep ALTER COLUMN id SET DEFAULT nextval('fac_nomina_det_percep_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_nomina_par ALTER COLUMN id SET DEFAULT nextval('fac_nomina_par_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_par ALTER COLUMN id SET DEFAULT nextval('fac_par_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_app ALTER COLUMN id SET DEFAULT nextval('gral_app_id_seq'::regclass);


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

ALTER TABLE ONLY gral_cons ALTER COLUMN id SET DEFAULT nextval('gral_cons_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_cons_tipos ALTER COLUMN id SET DEFAULT nextval('gral_cons_tipos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_deptos ALTER COLUMN id SET DEFAULT nextval('gral_deptos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_deptos_turnos ALTER COLUMN id SET DEFAULT nextval('gral_deptos_turnos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_dias_no_laborables ALTER COLUMN id SET DEFAULT nextval('gral_dias_no_laborables_id_seq'::regclass);


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

ALTER TABLE ONLY gral_empleado_deduc ALTER COLUMN id SET DEFAULT nextval('gral_empleado_deduc_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_empleado_percep ALTER COLUMN id SET DEFAULT nextval('gral_empleado_percep_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_empleados ALTER COLUMN id SET DEFAULT nextval('gral_empleados_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_ieps ALTER COLUMN id SET DEFAULT nextval('gral_ieps_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_imptos ALTER COLUMN id SET DEFAULT nextval('gral_imptos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_imptos_ret ALTER COLUMN id SET DEFAULT nextval('gral_imptos_ret_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_isr ALTER COLUMN id SET DEFAULT nextval('gral_isr_id_seq'::regclass);


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

ALTER TABLE ONLY gral_plazas ALTER COLUMN id SET DEFAULT nextval('gral_plazas_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_puestos ALTER COLUMN id SET DEFAULT nextval('gral_puestos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_reg ALTER COLUMN id SET DEFAULT nextval('gral_reg_id_seq'::regclass);


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

ALTER TABLE ONLY gral_suc_pza ALTER COLUMN id SET DEFAULT nextval('gral_suc_pza_id_seq'::regclass);


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
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_alm ALTER COLUMN id SET DEFAULT nextval('inv_alm_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_alm_tipos ALTER COLUMN id SET DEFAULT nextval('inv_alm_tipos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_clas ALTER COLUMN id SET DEFAULT nextval('inv_clas_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_exi ALTER COLUMN id SET DEFAULT nextval('inv_exi_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_kit ALTER COLUMN id SET DEFAULT nextval('inv_kit_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_mar ALTER COLUMN id SET DEFAULT nextval('inv_mar_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_mov_tipos ALTER COLUMN id SET DEFAULT nextval('inv_mov_tipos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_pre ALTER COLUMN id SET DEFAULT nextval('inv_pre_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_prod ALTER COLUMN id SET DEFAULT nextval('inv_prod_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_prod_cost_prom ALTER COLUMN id SET DEFAULT nextval('inv_prod_cost_prom_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_prod_familias ALTER COLUMN id SET DEFAULT nextval('inv_prod_familias_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_prod_grupos ALTER COLUMN id SET DEFAULT nextval('inv_prod_grupos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_prod_lineas ALTER COLUMN id SET DEFAULT nextval('inv_prod_lineas_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_prod_pres_x_prod ALTER COLUMN id SET DEFAULT nextval('inv_prod_pres_x_prod_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_prod_presentaciones ALTER COLUMN id SET DEFAULT nextval('inv_prod_presentaciones_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_prod_tipos ALTER COLUMN id SET DEFAULT nextval('inv_prod_tipos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_prod_unidades ALTER COLUMN id SET DEFAULT nextval('inv_prod_unidades_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_secciones ALTER COLUMN id SET DEFAULT nextval('inv_secciones_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_stock_clasificaciones ALTER COLUMN id SET DEFAULT nextval('inv_stock_clasificaciones_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_suc_alm ALTER COLUMN id SET DEFAULT nextval('inv_suc_alm_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_deduc ALTER COLUMN id SET DEFAULT nextval('nom_deduc_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_deduc_tipo ALTER COLUMN id SET DEFAULT nextval('nom_deduc_tipo_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_percep ALTER COLUMN id SET DEFAULT nextval('nom_percep_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_percep_tipo ALTER COLUMN id SET DEFAULT nextval('nom_percep_tipo_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_periodicidad_pago ALTER COLUMN id SET DEFAULT nextval('nom_periodicidad_pago_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_periodos_conf ALTER COLUMN id SET DEFAULT nextval('nom_periodos_conf_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_periodos_conf_det ALTER COLUMN id SET DEFAULT nextval('nom_periodos_conf_det_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_regimen_contratacion ALTER COLUMN id SET DEFAULT nextval('nom_regimen_contratacion_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_riesgo_puesto ALTER COLUMN id SET DEFAULT nextval('nom_riesgo_puesto_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_tipo_contrato ALTER COLUMN id SET DEFAULT nextval('nom_tipo_contrato_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_tipo_hrs_extra ALTER COLUMN id SET DEFAULT nextval('nom_tipo_hrs_extra_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_tipo_incapacidad ALTER COLUMN id SET DEFAULT nextval('nom_tipo_incapacidad_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_tipo_jornada ALTER COLUMN id SET DEFAULT nextval('nom_tipo_jornada_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY poc_pedidos ALTER COLUMN id SET DEFAULT nextval('poc_pedidos_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY poc_pedidos_detalle ALTER COLUMN id SET DEFAULT nextval('poc_pedidos_detalle_id_seq'::regclass);


--
-- Data for Name: ctb_may_clases; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY ctb_may_clases (id, titulo) FROM stdin;
1	Activo
2	Pasivo
3	Capital
4	Ingresos
5	Egresos
6	Cuentas de Orden
7	Perdidas y Ganancias
\.


--
-- Name: ctb_may_clases_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('ctb_may_clases_id_seq', 1, false);


--
-- Data for Name: cxc_clie; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxc_clie (id, numero_control, rfc, curp, razon_social, clave_comercial, calle, numero, entre_calles, numero_exterior, colonia, cp, pais_id, estado_id, municipio_id, localidad_alternativa, telefono1, extension1, fax, telefono2, extension2, email, cxc_agen_id, contacto, zona_id, cxc_clie_grupo_id, clienttipo_id, clasif_1, clasif_2, clasif_3, moneda, filial, estatus, gral_imp_id, limite_credito, dias_credito_id, credito_suspendido, credito_a_partir, cxp_prov_tipo_embarque_id, dias_caducidad_cotizacion, condiciones, observaciones, contacto_compras_nombre, contacto_compras_puesto, contacto_compras_calle, contacto_compras_numero, contacto_compras_colonia, contacto_compras_cp, contacto_compras_entre_calles, contacto_compras_pais_id, contacto_compras_estado_id, contacto_compras_municipio_id, contacto_compras_telefono1, contacto_compras_extension1, contacto_compras_fax, contacto_compras_telefono2, contacto_compras_extension2, contacto_compras_email, contacto_pagos_nombre, contacto_pagos_puesto, contacto_pagos_calle, contacto_pagos_numero, contacto_pagos_colonia, contacto_pagos_cp, contacto_pagos_entre_calles, contacto_pagos_pais_id, contacto_pagos_estado_id, contacto_pagos_municipio_id, contacto_pagos_telefono1, contacto_pagos_extension1, contacto_pagos_fax, contacto_pagos_telefono2, contacto_pagos_extension2, contacto_pagos_email, empresa_id, sucursal_id, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, id_usuario_creacion, id_usuario_actualizacion, id_usuario_baja, id_aux, empresa_immex, tasa_ret_immex, dia_revision, dia_pago, cta_pago_mn, cta_pago_usd, ctb_cta_id_activo, ctb_cta_id_ingreso, ctb_cta_id_ietu, ctb_cta_id_comple, ctb_cta_id_activo_comple, lista_precio, fac_metodos_pago_id, cxc_clie_tipo_adenda_id) FROM stdin;
1	1	XEXX010101000		PRODUMEX, USA	PRODUMEX	E. EXPRESSWAY 83	502			SAN JUAN	78589	1	33	2457		8112345678					compras@produmex.com	4		1	1	1	1	1	1	1	f	t	1	0	1	f	2	0	0										0	0	0														0	0	0							1	1	f	2016-08-10 00:00:00-04	2016-08-16 22:27:04.6372-04	\N	1	1	0	\N	f	0	0	0			0	0	0	0	0	1	1	0
\.


--
-- Data for Name: cxc_clie_clas1; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxc_clie_clas1 (id, titulo) FROM stdin;
1	CLASIF 1
2	CLASIF 2
\.


--
-- Name: cxc_clie_clas1_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxc_clie_clas1_id_seq', 1, false);


--
-- Data for Name: cxc_clie_clas2; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxc_clie_clas2 (id, titulo) FROM stdin;
1	CLASIF 1
2	CLASIF 2
\.


--
-- Name: cxc_clie_clas2_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxc_clie_clas2_id_seq', 1, false);


--
-- Data for Name: cxc_clie_clas3; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxc_clie_clas3 (id, titulo) FROM stdin;
1	CLASIF 1
2	CLASIF 2
\.


--
-- Name: cxc_clie_clas3_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxc_clie_clas3_id_seq', 1, false);


--
-- Data for Name: cxc_clie_clases; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxc_clie_clases (id, titulo, borrado_logico) FROM stdin;
1	NACIONAL	f
2	EXTRANJERO	f
\.


--
-- Name: cxc_clie_clases_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxc_clie_clases_id_seq', 1, false);


--
-- Data for Name: cxc_clie_creapar; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxc_clie_creapar (id, titulo) FROM stdin;
1	FECHA DE EMBARQUE
2	FECHA DE FACTURA
3	FECHA DE RECEPCION
\.


--
-- Name: cxc_clie_creapar_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxc_clie_creapar_id_seq', 1, false);


--
-- Data for Name: cxc_clie_credias; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxc_clie_credias (id, descripcion, dias, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, tipo_cambio, id_usuario_creacion, id_usuario_actualizacion, id_usuario_baja, sucursal_id) FROM stdin;
1	CONTADO	1	f	2012-02-09 01:00:00-05	\N	\N	0	1	1	0	1
2	15 DIAS	15	f	2012-02-09 01:00:00-05	\N	\N	0	1	1	0	1
3	30 DIAS	30	f	2012-02-10 01:00:00-05	\N	\N	0	1	1	0	1
4	45 DIAS	40	f	2012-02-10 01:00:00-05	\N	\N	0	1	1	0	1
5	60 DIAS	60	f	2012-02-10 01:00:00-05	\N	\N	0	1	1	0	1
6	90 DIAS	90	f	2012-02-10 01:00:00-05	\N	\N	0	1	1	0	1
7	180 DIAS	180	f	2012-02-10 01:00:00-05	\N	\N	0	1	1	0	1
8	10 DIAS	10	f	2012-02-10 01:00:00-05	\N	\N	0	1	1	0	1
\.


--
-- Name: cxc_clie_credias_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxc_clie_credias_id_seq', 1, false);


--
-- Data for Name: cxc_clie_descto; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxc_clie_descto (id, cxc_clie_id, tipo, valor) FROM stdin;
\.


--
-- Name: cxc_clie_descto_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxc_clie_descto_id_seq', 1, false);


--
-- Data for Name: cxc_clie_df; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxc_clie_df (id, cxc_clie_id, calle, numero_interior, numero_exterior, entre_calles, colonia, cp, gral_pais_id, gral_edo_id, gral_mun_id, telefono1, extension1, telefono2, extension2, fax, email, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gra_usr_id_creacion, gra_usr_id_actualizacion, gra_usr_id_baja, contacto) FROM stdin;
1	0	ESTE ES PARA LA LLAVE FORANEA DE LA DIRECCION DEFAULT DEL CLIENTE	DEFAULT	DEFAULT	DEFAULT	DEFAULT	DEFAULT	1	1	1	DEFAULT	DEFAULT	DEFAULT	DEFAULT	DEFAULT	DEFAULT	t	\N	\N	\N	1	1	1	DEFAULT
\.


--
-- Name: cxc_clie_df_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxc_clie_df_id_seq', 1, false);


--
-- Data for Name: cxc_clie_grupos; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxc_clie_grupos (id, titulo, borrado_logico) FROM stdin;
1	LOS MAGNIFICOS	f
\.


--
-- Name: cxc_clie_grupos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxc_clie_grupos_id_seq', 1, false);


--
-- Name: cxc_clie_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxc_clie_id_seq', 2, true);


--
-- Data for Name: cxc_clie_tipos_embarque; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxc_clie_tipos_embarque (id, titulo) FROM stdin;
1	TERRESTRE
2	AEREO
3	MARITIMO
\.


--
-- Name: cxc_clie_tipos_embarque_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxc_clie_tipos_embarque_id_seq', 1, false);


--
-- Data for Name: cxc_clie_zonas; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxc_clie_zonas (id, titulo, borrado_logico) FROM stdin;
1	ZONA_A	f
\.


--
-- Name: cxc_clie_zonas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxc_clie_zonas_id_seq', 1, false);


--
-- Data for Name: cxp_prov; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxp_prov (id, folio, rfc, curp, razon_social, clave_comercial, calle, numero, colonia, cp, entre_calles, pais_id, estado_id, municipio_id, localidad_alternativa, telefono1, extension1, fax, telefono2, extension2, correo_electronico, web_site, impuesto, cxp_prov_zona_id, grupo_id, proveedortipo_id, clasif_1, clasif_2, clasif_3, moneda_id, tiempo_entrega_id, estatus, limite_credito, dias_credito_id, descuento, credito_a_partir, cxp_prov_tipo_embarque_id, flete_pagado, condiciones, observaciones, vent_contacto, vent_puesto, vent_calle, vent_numero, vent_colonia, vent_cp, vent_entre_calles, vent_pais_id, vent_estado_id, vent_municipio_id, vent_telefono1, vent_extension1, vent_fax, vent_telefono2, vent_extension2, vent_email, cob_contacto, cob_puesto, cob_calle, cob_numero, cob_colonia, cob_cp, cob_entre_calles, cob_pais_id, cob_estado_id, cob_municipio_id, cob_telefono1, cob_extension1, cob_fax, cob_telefono2, cob_extension2, cob_email, comentarios, empresa_id, sucursal_id, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, id_usuario_creacion, id_usuario_actualizacion, id_usuario_baja, ctb_cta_id_pasivo, ctb_cta_id_egreso, ctb_cta_id_ietu, ctb_cta_id_comple, ctb_cta_id_pasivo_comple, transportista) FROM stdin;
4	4	AIN0307228S4		ABARROTES INTERNACIONALES, S.A. DE C.V.	ABARROTES	MIGUEL NIETO SUR	660-A	CENTRO\n	64000\n		2	19	973									1	1	1	1	1	1	1	1	0	t	0	1	0	3	0	t										0	0	0														0	0	0								1	1	f	\N	\N	\N	1	0	0	0	0	0	0	0	f
5	5	GAME791116E65		ELEAZAR GARCIA MATA	GARCIA	CARRETERA NACIONAL	S/N	CENTRO	67350	CRUZ CON FRANCISCO I. MADERO	2	19	951		6188126639					nobody@usa.net		1	1	1	1	1	1	1	1	0	t	0	1	0	3	0	t			SIN CONTACTO	SIN PUESTO						1	0	0														0	0	0								1	1	f	\N	2016-08-15 22:09:25.845764-04	\N	1	1	0	0	0	0	0	0	f
6	6	TAFH8004043V4		HELIODORO DANIEL TAMEZ FLORES	TAMEZ	MORELOS NORTE	1708	IGNACIO ZARAGOZA	67350		2	19	951		6188126639					nobody@usa.net		1	1	1	1	1	1	1	1	0	t	0	1	0	3	0	t			SIN CONTACTO	SIN PUESTO						1	0	0														0	0	0								1	1	f	\N	2016-08-15 22:10:38.40795-04	\N	1	1	0	0	0	0	0	0	f
1	1	ESR130812TGA		EXPORTACIONES SUAREZ RODRIGUEZ, S.A. DE C.V.	SUAREZ	EL MAIZAL	307	HACIENDA SAN MIGUEL	67113		2	19	973		8181311100					DDD@JJ.COM		1	1	1	1	1	1	1	1	0	t	0	1	0	3	0	t			SS	SS						1	0	0														0	0	0								1	1	f	2014-12-19 05:13:58.229361-05	2016-08-15 22:03:27.072272-04	\N	1	1	0	0	0	0	0	0	f
2	2	OOPS631111741		SALVADOR ORDOÑEZ PEÑA	SALVADOR	JOSE MARIANO SLAS	506	REGINA	64290		2	19	986		6188126639					nobody@usa.net		1	1	1	1	1	1	1	1	0	t	0	1	0	3	0	t			SIN CONTACTO	SIN PUESTO						1	0	0														0	0	0								1	1	f	\N	2016-08-15 22:04:16.414042-04	\N	1	1	0	0	0	0	0	0	f
3	3	BANM810417643		MANUEL BAUTISTA NOGALES	MANUEL	AV. PEDRERAS	103	SANTA MARIA	66368		2	19	995		6188126639					nobody@usa.net		1	1	1	1	1	1	1	1	0	t	0	1	0	3	0	t			SIN CONTACTO	SIN PUESTO						1	0	0														0	0	0								1	1	f	\N	2016-08-15 22:06:36.529614-04	\N	1	1	0	0	0	0	0	0	f
10	10	VID050520755		VIDEMONT, S.A. DE C.V.	VIDE	RIO CAURA	350	DEL VALLE	66220		2	19	965		6188126639					nobody@usa.net		1	1	1	1	1	1	1	1	0	t	0	1	0	3	0	t			SIN CONTACTO	SIN PUESTO						1	0	0														0	0	0								1	1	f	\N	2016-08-15 22:18:52.506841-04	\N	1	1	0	0	0	0	0	0	f
7	7	PMO0212117P6		PALACIOS MORENO, S.A. DE C.V.	PALACIOS	PRIV. PRIMERA	S/N	LOS RODRIGUEZ	67300		2	19	996		6188126639					nobody@usa.net		1	1	1	1	1	1	1	1	0	t	0	1	0	3	0	t			SIN CONTACTO	SIN PUESTO						1	0	0														0	0	0								1	1	f	\N	2016-08-15 22:13:25.299936-04	\N	1	1	0	0	0	0	0	0	f
8	8	GBI921016985		GASOLINERA BALLESTEROA IBARRA, S.A. DE C.V.	GAS_BALLES	EMPACADORAS	S/N	CENTRO	67500		2	19	985		6188126639					nobody@usa.net		1	1	1	1	1	1	1	1	0	t	0	1	0	3	0	t			SIN CONTACTO	SIN PUESTO						1	0	0														0	0	0								1	1	f	\N	2016-08-15 22:13:39.467306-04	\N	1	1	0	0	0	0	0	0	f
9	9	SCT8411179Q4		SOCIEDAD COOPERATIVA TRABAJADORES DE PASCUAL, S.C.L.	TRA_PAS	CLAVIJERO	60	TRANSITO	06820		2	9	279		6188126639					nobody@usa.net		1	1	1	1	1	1	1	1	0	t	0	1	0	3	0	t			SIN CONTACTO	SIN PUESTO						1	0	0														0	0	0								1	1	f	\N	2016-08-15 22:16:29.612829-04	\N	1	1	0	0	0	0	0	0	f
11	11	FERE9412086C6		JOSE ELIAS FERNANDEZ RIOS	FER_RIOS	BLOCK	K-6	CENTRAL DE ABASTOS	20280		2	1	1		6188126639					nobody@usa.net		1	1	1	1	1	1	1	1	0	t	0	1	0	3	0	t			SIN CONTACTO	SIN PUESTO						1	0	0														0	0	0								1	1	f	\N	2016-08-15 22:19:36.654806-04	\N	1	1	0	0	0	0	0	0	f
12	12	CAMP8502017C2		MARCO ANTONIO CAMARENA PADILLA	CAMARENA	COLON	386	CENTRO	47600		2	14	624		6188126639					nobody@usa.net		1	1	1	1	1	1	1	1	0	t	0	1	0	3	0	t			SIN CONTACTO	SIN PUESTO						1	0	0														0	0	0								1	1	f	\N	2016-08-15 22:21:18.681457-04	\N	1	1	0	0	0	0	0	0	f
18	18	EOC1303232N8		EXPRESS OCA, S.A. DE C.V.	EXPRESS	LOS ANGELES	1000	GARZA CANTU	66480		2	19	993		6188126639					nobody@usa.net		1	1	1	1	1	1	1	1	0	t	0	1	0	3	0	t			SIN CONTACTO	SIN PUESTO						1	0	0														0	0	0								1	1	f	\N	2016-08-15 22:24:22.579712-04	\N	1	1	0	0	0	0	0	0	f
17	17	FUGA490413B41		ARMANDINA GLORIA FUENTES GARZA	ARMANDINA	ESCOBEDO	106	CENTRO	67500		2	19	985		6188126639					nobody@usa.net		1	1	1	1	1	1	1	1	0	t	0	1	0	3	0	t			SIN CONTACTO	SIN PUESTO						1	0	0														0	0	0								1	1	f	\N	2016-08-15 22:25:44.279908-04	\N	1	1	0	0	0	0	0	0	f
13	13	HRL1309192M5		HEINIX RUAN LABELS, S.A. DE C.V.	HEINIX	VENUSTIANO CARRANZA	203-A	CENTRO	67350		2	19	951		6188126639					nobody@usa.net		1	1	1	1	1	1	1	1	0	t	0	1	0	3	0	t			SIN CONTACTO	SIN PUESTO						1	0	0														0	0	0								1	1	f	\N	2016-08-15 22:31:08.479886-04	\N	1	1	0	0	0	0	0	0	f
15	15	CCA0108206P8		CANTU CEPEDA Y ASOCIADOS, S.C.	CANTU	PRIV. MARIANO ESCOBEDO	810	FRACC. LOS SAUCES 2O. SECTOR	66237		2	19	965		8183324193			8116658702		mcantudiaz@hotmail.com		1	1	1	1	1	1	1	1	0	t	0	1	0	3	0	t			SIN CONTACTO	SIN PUESTO						1	0	0														0	0	0								1	1	f	\N	2016-08-15 22:43:08.383451-04	\N	1	1	0	0	0	0	0	0	f
14	14	IAS140311699		IASERO, S.A. DE C.V.	IASERO	ZARAGOZA	805	VALLE DORADO	67350		2	19	951		6188126639					nobody@usa.net		1	1	1	1	1	1	1	1	0	t	0	1	0	3	0	t			SIN CONTACTO	SIN PUESTO						1	0	0														0	0	0								1	1	f	\N	2016-08-15 22:45:41.946569-04	\N	1	1	0	0	0	0	0	0	f
16	16	SES1408145U3		SOLUCIONES EN EMPAQUE Y SUMINISTROS, S.A. DE C.V.	EMPAQUES	BLVD. JOSE MARIA GONZALEZ	221	JARDINES DE CAPELLANIA	67484		2	19	956		6188126638					nobody@usa.net		1	1	1	1	1	1	1	1	0	t	0	1	0	3	0	t			SIN CONTACTO	SIN PUESTO						1	0	0														0	0	0								1	1	f	\N	2016-08-15 23:09:57.888621-04	\N	1	1	0	0	0	0	0	0	f
20	20	CDN150527MQ8		COMERCIO DINAMICO DEL NORESTE, S.A. DE C.V.	DINAMICO	AV. HUMBERTO LOBO	9442	PARQUE INDUSTRIAL MITRAS	66000		2	19	965		6188126639					nobody@usa.net		1	1	1	1	1	1	1	1	0	t	0	1	0	3	0	t			SIN CONTACTO	SIN PUESTO						1	0	0														0	0	0								1	1	f	\N	2016-08-15 22:00:06.683281-04	\N	1	1	0	0	0	0	0	0	f
19	19	LOTG750911887		GENARO DE JESUS LOPEZ TAMEZ	GENARO	JOSE MARIA PINO SUAREZ	603	CENTRO	67700		2	19	980		6188126639					nobody@usa.net		1	1	1	1	1	1	1	1	0	t	0	1	0	3	0	t			SIN CONTACTO	SIN PUESTO						1	0	0														0	0	0								1	1	f	\N	2016-08-15 22:23:36.598134-04	\N	1	1	0	0	0	0	0	0	f
\.


--
-- Data for Name: cxp_prov_clas1; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxp_prov_clas1 (id, titulo, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja, gral_emp_id, gral_suc_id) FROM stdin;
1	CLASE 1	f	2012-09-05 08:12:12-04	\N	\N	1	0	0	1	1
\.


--
-- Name: cxp_prov_clas1_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxp_prov_clas1_id_seq', 1, false);


--
-- Data for Name: cxp_prov_clas2; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxp_prov_clas2 (id, titulo, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja, gral_emp_id, gral_suc_id) FROM stdin;
1	CLASE 2	f	2012-09-05 08:12:12-04	\N	\N	1	0	0	1	1
\.


--
-- Name: cxp_prov_clas2_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxp_prov_clas2_id_seq', 1, false);


--
-- Data for Name: cxp_prov_clas3; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxp_prov_clas3 (id, titulo, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja, gral_emp_id, gral_suc_id) FROM stdin;
1	CLASE 3	f	2012-09-05 08:12:12-04	\N	\N	1	0	0	1	1
\.


--
-- Name: cxp_prov_clas3_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxp_prov_clas3_id_seq', 1, false);


--
-- Data for Name: cxp_prov_clases; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxp_prov_clases (id, titulo) FROM stdin;
1	CLASE 1
\.


--
-- Name: cxp_prov_clases_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxp_prov_clases_id_seq', 1, false);


--
-- Data for Name: cxp_prov_contactos; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxp_prov_contactos (id, contacto, proveedor_id, telefono, email, fax) FROM stdin;
1	aaaa	1	8126639	nobody@gmail.com	\N
2	bbbb	2	8126639	nobody@gmail.com	\N
3	cccc	3	8126639	pianodaemon@gmail.com	\N
4	dddd	4	8126639	j4nusx@yahoo.com	\N
5	eeee	5	8126639	j4nusx@excite.com	\N
6	ffff	6	8126639	plauchu@usa.net	\N
7	gggg	7	8126639	eplauchu@intel.com	\N
8	hhhh	8	8126639	otelo@usa.net	\N
9	iiii	9	8126639	plauchu@gmail.com	\N
10	jjjj	10	8126639	homero@simpsons.com	\N
11	kkkk	11	8126639	bart@simpsons.com	\N
12	llll	12	8126639	lisa@simpsons.com	\N
13	mmmm	13	8126639	marge@simpson.com	\N
14	yyyy	14	8126639	maggie@simpsons.com	\N
15	xxxx	15	8126639	j4nusx@starmedia.com	\N
16	none	16	8126639	enjoy@thesilence.com	\N
17	chanfle	17	8126639	chaparron@bonaparte.com	\N
18	lao tse	18	8126639	tao@filosofo.org	\N
19	sidartha	19	8126639	buda@panzon.com	\N
20	sasha	20	8126639	sasha@eres.com	\N
\.


--
-- Name: cxp_prov_contactos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxp_prov_contactos_id_seq', 20, true);


--
-- Data for Name: cxp_prov_creapar; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxp_prov_creapar (id, titulo) FROM stdin;
1	Fecha de Embarque
2	Fecha de Recepcion
3	Fecha de Factura
\.


--
-- Name: cxp_prov_creapar_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxp_prov_creapar_id_seq', 1, false);


--
-- Data for Name: cxp_prov_credias; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxp_prov_credias (id, descripcion, dias) FROM stdin;
1	Contado	1
2	8 dias	8
3	15 dias	15
4	30 dias	30
5	45 dias	45
6	60 dias	60
7	90 dias	90
8	180 dias	180
\.


--
-- Name: cxp_prov_credias_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxp_prov_credias_id_seq', 1, false);


--
-- Data for Name: cxp_prov_fleteras; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxp_prov_fleteras (id, razon_social, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, empresa_id, sucursal_id) FROM stdin;
1	FLETES ANONIMOS S.A. DE C.V.	f	2012-09-05 08:12:12-04	\N	\N	1	1
2	FLETES DEL NORTE S.A. DE C.V.	f	2012-09-05 08:12:12-04	\N	\N	1	1
\.


--
-- Name: cxp_prov_fleteras_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxp_prov_fleteras_id_seq', 2, true);


--
-- Data for Name: cxp_prov_grupos; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxp_prov_grupos (id, titulo, borrado_logico) FROM stdin;
1	Grupo 1	f
\.


--
-- Name: cxp_prov_grupos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxp_prov_grupos_id_seq', 1, false);


--
-- Name: cxp_prov_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxp_prov_id_seq', 28, true);


--
-- Data for Name: cxp_prov_tipos_embarque; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxp_prov_tipos_embarque (id, titulo) FROM stdin;
1	Terrestre
2	Aereo
3	Maritimo
\.


--
-- Name: cxp_prov_tipos_embarque_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxp_prov_tipos_embarque_id_seq', 1, false);


--
-- Data for Name: cxp_prov_zonas; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY cxp_prov_zonas (id, titulo) FROM stdin;
1	Zona 1
2	Zona 2
\.


--
-- Name: cxp_prov_zonas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('cxp_prov_zonas_id_seq', 2, true);


--
-- Data for Name: erp_clients_consignacions; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY erp_clients_consignacions (id, cliente_id, calle, numero, colonia, pais, entidad, localidad, cp, localidad_alternativa, telefono, fax, momento_creacion, pais_id, estado_id, municipio_id) FROM stdin;
\.


--
-- Name: erp_clients_consignacions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('erp_clients_consignacions_id_seq', 1, false);


--
-- Data for Name: erp_h_facturas; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY erp_h_facturas (id, cliente_id, serie_folio, monto_total, moneda_id, tipo_cambio, pagado, total_pagos, total_pagos_cancelados, saldo_factura, total_notas_creditos, total_saldoa_favor, total_anticipos, momento_facturacion, cancelacion, momento_cancelacion, momento_actualizacion, id_usuario_creacion, id_usuario_cancelacion, empresa_id, sucursal_id, fac_docs_tipo_cancelacion_id, cxc_agen_id, fecha_vencimiento, estatus_revision, orden_compra, enviado, fecha_ultimo_pago, subtotal, impuesto, retencion, monto_ieps) FROM stdin;
\.


--
-- Name: erp_h_facturas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('erp_h_facturas_id_seq', 1, false);


--
-- Data for Name: erp_mascaras_para_validaciones_por_app; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY erp_mascaras_para_validaciones_por_app (app_id, mask_name, mask_regex, id) FROM stdin;
4	is_NombreCorrect	^[ a-zA-Z]{1,30}$	17
4	is_ApellidopaternoCorrect	^[ a-zA-Z]{1,30}$	18
4	is_CalleCorrect	.{1,45}$	19
4	is_AddressNumberCorrect	^.{1,5}$	20
4	is_ColoniaCorrect	.{1,45}$	21
4	is_CorreopersonalCorrect	^[^@ ]+@[^@ ]+.[^@ .]+$	22
4	is_CpCorrect	^[0-9]{5}$	23
4	is_CurpCorrect	^[A-Za-z]{4}[0-9]{6}[A-Za-z]{6}[A-Za-z0-9]{1}[0-9]{1}$	24
4	is_RFCCorrect	^[A-Za-z0-9&]{3,4}[0-9]{6}[A-Za-z0-9]{0,3}$	25
4	is_FechaNacIngCorrect	^[0-9]{4}[-]{1}[0-9]{2}[-]{1}[0-9]{2}$	26
4	is_ImssCorrect	^[0-9]{11}$	27
4	is_PhoneCorrect	^[0-9]{10}$	28
2	is_CurpCorrect	^[A-Za-z]{4}[0-9]{6}[A-Za-z]{6}[A-Za-z0-9]{1}[0-9]{1}$	72
2	is_RazonSocialCorrect	.{1,100}	15
2	is_ContactoCorrect	.{1,45}	14
2	is_EmailCorrect	^[^@ ]+@[^@ ]+.[^@ .]+$	13
2	is_PhoneCorrect	^[0-9]{10}$	12
2	is_RFCCorrect	^[A-Za-z0-9&]{3,4}[0-9]{6}[A-Za-z0-9]{3}$	11
2	is_CalleCorrect	.{1,45}$	10
2	is_ColoniaCorrect	.{1,45}$	9
2	is_AddressNumberCorrect	^.{1,5}$	7
2	is_TituloCorrerct	^.{1,25}$	6
2	is_CodigoPostalCorrect	^[0-9]{5,6}$	8
4	is_InfonavitCorrect	^[0-9]{11}$	86
4	is_UserCorrect	[A-Za-z0-9]{1,5}	87
4	is_PasswordCorrect	[A-Za-z0-9]{1,5}	88
4	is_ComisionCorrect	^([0-9]){1,12}[.]?[0-9]*$	89
4	is_Comision2Correct	^([0-9]){1,12}[.]?[0-9]*$	90
4	is_Comision3Correct	^([0-9]){1,12}[.]?[0-9]*$	91
4	is_Comision4Correct	^([0-9]){1,12}[.]?[0-9]*$	92
4	is_DiascomisionCorrect	^([0-9]){1,12}[.]?[0-9]*$	93
4	is_Diascomision2Correct	^([0-9]){1,12}[.]?[0-9]*$	94
4	is_DiasComision3Correct	^([0-9]){1,12}[.]?[0-9]*$	95
4	is_FechaInicioCorrect	^[0-9]{4}[-]{1}[0-9]{2}[-]{1}[0-9]{2}$	96
4	is_ApellidomaternoCorrect	^[ a-zA-Z]{1,30}$	97
5	is_RFCCorrect	^[A-Za-z0-9&]{3,4}[0-9]{6}[A-Za-z0-9]{0,3}$	32
5	is_CalleCorrect	.{1,45}$	33
5	is_ColoniaCorrect	.{1,45}$	35
5	is_CpCorrect	^[0-9]{5}$	36
5	is_PhoneCorrect	^[0-9]{10}$	37
5	is_CorreoCorrect	^[^@ ]+@[^@ ]+.[^@ .]+$	38
5	is_NocontrolCorrect	^[a-zA-Z]{1}[0-9]{1,9}$	29
5	is_RazonsocialCorrect	[\\w .]	30
5	is_CurpCorrect	^[A-Za-z]{4}[0-9]{6}[A-Za-z]{6}[A-Za-z0-9]{1}[0-9]{1}$	31
5	is_AddressNumberCorrect	[A-Za-z0-9]{1,5}	34
5	is_LegacyidCorrect	^[0-9]+$	66
8	is_SkuCorrect	.{1,30}$	55
8	is_TituloesCorrect	.{1,50}$	56
8	is_DescripcionesCorrect	.{1,120}$	58
8	is_DescripcionenCorrect	.{1,120}$	59
8	is_TituloenCorrect	.{1,50}$	57
\.


--
-- Name: erp_mascaras_para_validaciones_por_app_app_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('erp_mascaras_para_validaciones_por_app_app_id_seq', 1, false);


--
-- Data for Name: erp_monedavers; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY erp_monedavers (id, valor, momento_creacion, moneda_id, version) FROM stdin;
1	18.9116999999999997	2016-08-04 10:15:30.181524-04	2	DOF
2	18.9116999999999997	2016-08-06 10:04:37.959918-04	2	DOF
3	18.8690999999999995	2016-08-08 19:25:43.893056-04	2	DOF
4	18.3478999999999992	2016-08-11 12:18:21.565737-04	2	DOF
5	18.2678000000000011	2016-08-12 23:22:45.78109-04	2	DOF
6	18.2678000000000011	2016-08-13 10:23:34.936361-04	2	DOF
7	18.2454999999999998	2016-08-15 20:25:09.535235-04	2	DOF
8	18.0363000000000007	2016-08-16 15:10:37.367853-04	2	DOF
9	17.9868999999999986	2016-08-17 09:49:07.721927-04	2	DOF
10	18.2597999999999985	2016-08-18 08:57:02.253714-04	2	DOF
11	18.0832000000000015	2016-08-19 15:59:27.174621-04	2	DOF
12	18.0832000000000015	2016-08-20 21:23:23.017334-04	2	DOF
13	18.0832000000000015	2016-08-21 10:20:10.427693-04	2	DOF
14	18.2673999999999985	2016-08-22 16:39:32.445811-04	2	DOF
15	18.3022999999999989	2016-08-23 11:07:48.320334-04	2	DOF
\.


--
-- Name: erp_monedavers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('erp_monedavers_id_seq', 15, true);


--
-- Data for Name: erp_pagos_formas; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY erp_pagos_formas (id, titulo, borrado_logico) FROM stdin;
1	Efectivo	f
2	Cheque	f
3	Tarjeta	f
4	Transferencia	f
5	Nota Credito	f
\.


--
-- Name: erp_pagos_formas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('erp_pagos_formas_id_seq', 1, false);


--
-- Data for Name: erp_parametros_generales; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY erp_parametros_generales (id, variable, valor) FROM stdin;
1	tasa_retencion_fletes	4
2	tipo_impuesto	1
3	tipo_facturacion	cfd
\.


--
-- Name: erp_parametros_generales_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('erp_parametros_generales_id_seq', 1, false);


--
-- Data for Name: erp_prefacturas; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY erp_prefacturas (id, cliente_id, moneda_id, observaciones, subtotal, impuesto, total, proceso_id, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, tipo_cambio, id_usuario_creacion, id_usuario_actualizacion, id_usuario_baja, empleado_id, terminos_id, orden_compra, factura_sai, factura_id, refacturar, fac_metodos_pago_id, no_cuenta, monto_retencion, tasa_retencion_immex, tipo_documento, folio_pedido, enviar_ruta, inv_alm_id, id_moneda_pedido, cxc_clie_df_id, fac_subtotal, fac_impuesto, fac_monto_retencion, fac_total, monto_ieps, fac_monto_ieps, monto_descto, fac_monto_descto, motivo_descto, ctb_tmov_id) FROM stdin;
\.


--
-- Data for Name: erp_prefacturas_detalles; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY erp_prefacturas_detalles (id, prefacturas_id, producto_id, presentacion_id, tipo_impuesto_id, cantidad, precio_unitario, momento_creacion, valor_imp, costo_promedio, reservado, costo_referencia, cant_facturado, facturado, cant_facturar, inv_prod_unidad_id, gral_ieps_id, valor_ieps, descto, fac_rem_det_id, gral_imptos_ret_id, tasa_ret) FROM stdin;
\.


--
-- Name: erp_prefacturas_detalles_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('erp_prefacturas_detalles_id_seq', 1, false);


--
-- Name: erp_prefacturas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('erp_prefacturas_id_seq', 1, false);


--
-- Data for Name: erp_proceso; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY erp_proceso (id, proceso_flujo_id, empresa_id, sucursal_id) FROM stdin;
\.


--
-- Data for Name: erp_proceso_flujo; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY erp_proceso_flujo (id, titulo) FROM stdin;
1	COTIZACION
3	FACTURADO
4	PEDIDO
2	FACTURACION
5	REMISION
6	ORDEN SALIDA
7	FAC PARCIAL
8	REM PARCIAL
\.


--
-- Name: erp_proceso_flujo_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('erp_proceso_flujo_id_seq', 1, false);


--
-- Name: erp_proceso_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('erp_proceso_id_seq', 1, false);


--
-- Data for Name: erp_tiempos_entrega; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY erp_tiempos_entrega (id, descripcion) FROM stdin;
1	12 hrs
2	24 hrs
3	36 hrs
4	48 hrs
5	72 hrs
6	1 semana
7	2 semanas
8	3 semanas
9	1 mes
\.


--
-- Name: erp_tiempos_entrega_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('erp_tiempos_entrega_id_seq', 9, true);


--
-- Data for Name: fac_cfds_conf; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY fac_cfds_conf (empresa_id, archivo_certificado, numero_certificado, archivo_llave, password_llave, id, gral_suc_id, archivo_xsl, archivo_xsd_cfdi, archivo_wsdl_timbrado_cfdi, ws_pfx_cert, passwd_ws_pfx, javavm_dir, javavm_cacerts, archivo_xsl_cadena_timbre, usuario, contrasena, archivo_xsl_cadena_ctas_contables, archivo_xsd_ctas_contables, archivo_xsl_cadena_balanza_comprobacion) FROM stdin;
1	00001000000301698966.cer	00001000000301698966	CSD_EXPORTACIONES_SUMAR_SA_DE_CV_ESU131122SZ6_20131211_122743.key	Esu131122	1	1	cadenaoriginal_3_2.xslt	cfdv32.xsd	TimbradoCFDI.wsdl	AAA010101AAA.pfx	AAA010101AAA	/usr/bin/java	/home/j2eeserver/jdk/jre/lib/security/cacerts	cadena_original_timbre.xslt	195	G3rM4rAr45aLaVi	CatalogoCuentas_1_1.xslt	CatalogoCuentas_1_1.xsd	BalanzaComprobacion_1_1.xslt
\.


--
-- Name: fac_cfds_conf_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('fac_cfds_conf_id_seq', 1, true);


--
-- Data for Name: fac_metodos_pago; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY fac_metodos_pago (id, titulo, borrado_logico, clave_sat, momento_creacion, momento_actualiza, momento_baja, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja, gral_emp_id) FROM stdin;
2	TARJETA CREDITO	f	04	2016-07-14 14:22:35.326858-04	2016-07-14 15:32:37.553596-04	\N	\N	1	\N	1
3	TARJETA DEBITO	f	28	2016-07-14 14:22:35.326858-04	2016-07-14 15:32:58.824791-04	\N	\N	1	\N	1
7	OTROS	f	99	2016-07-14 14:22:35.326858-04	2016-07-14 15:33:21.478416-04	\N	\N	1	\N	1
6	MONEDEROS ELECTRÓNICOS	f	05	2016-07-14 14:22:35.326858-04	2016-07-14 15:33:41.761163-04	\N	\N	1	\N	1
1	EFECTIVO	f	01	2016-07-14 14:22:35.326858-04	2016-07-14 14:36:15.772894-04	\N	\N	1	\N	1
4	CHEQUE NOMINATIVO	f	02	2016-07-14 14:22:35.326858-04	2016-07-14 15:31:58.715889-04	\N	\N	1	\N	1
5	TRANSFERENCIA ELECTRONICA DE FONDOS	f	03	2016-07-14 14:22:35.326858-04	2016-07-14 15:32:18.792891-04	\N	\N	1	\N	1
\.


--
-- Name: fac_metodos_pago_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('fac_metodos_pago_id_seq', 1, false);


--
-- Data for Name: fac_namespaces; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY fac_namespaces (id, key_xmlns, xmlns, schemalocation, fac, fac_nomina, derogado, fecha_derogacion) FROM stdin;
3	xmlns:tfd	http://www.sat.gob.mx/TimbreFiscalDigital	http://www.sat.gob.mx/TimbreFiscalDigital http://www.sat.gob.mx/sitio_internet/TimbreFiscalDigital/TimbreFiscalDigital.xsd	t	t	f	\N
\.


--
-- Name: fac_namespaces_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('fac_namespaces_id_seq', 1, false);


--
-- Data for Name: fac_nomina; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY fac_nomina (id, tipo_comprobante, forma_pago, tipo_cambio, no_cuenta, fecha_pago, fac_metodos_pago_id, gral_mon_id, nom_periodicidad_pago_id, nom_periodos_conf_det_id, momento_creacion, momento_actualizacion, momento_baja, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja, gral_emp_id, gral_suc_id, status) FROM stdin;
72	EGRESO	PAGO EN UNA SOLA EXIBICION	1		2016-07-29	4	1	1	17	2016-08-23 13:24:16.121344-04	\N	\N	1	0	0	1	1	0
73	EGRESO	PAGO EN UNA SOLA EXIBICION	1		2016-08-05	4	1	1	18	2016-08-23 13:39:24.720854-04	2016-08-23 13:42:07.307362-04	\N	1	1	0	1	1	0
74	EGRESO	PAGO EN UNA SOLA EXIBICION	1		2016-08-12	4	1	1	19	2016-08-23 13:44:05.673497-04	2016-08-23 13:46:24.132163-04	\N	1	1	0	1	1	0
54	EGRESO	PAGO EN UNA SOLA EXIBICION	1		2016-04-15	4	1	1	2	2016-08-23 11:22:38.225531-04	2016-08-23 11:24:11.840871-04	\N	1	1	0	1	1	0
56	EGRESO	PAGO EN UNA SOLA EXIBICION	1		2016-04-22	4	1	1	3	2016-08-23 11:27:15.57167-04	\N	\N	1	0	0	1	1	0
57	EGRESO	PAGO EN UNA SOLA EXIBICION	1		2016-04-29	4	1	1	4	2016-08-23 11:30:07.868303-04	2016-08-23 11:31:21.817712-04	\N	1	1	0	1	1	0
53	EGRESO	PAGO EN UNA SOLA EXIBICION	1		2016-04-08	4	1	1	1	2016-08-23 11:17:31.674088-04	2016-08-23 11:36:00.433801-04	\N	1	1	0	1	1	0
59	EGRESO	PAGO EN UNA SOLA EXIBICION	1		2016-05-06	4	1	1	5	2016-08-23 12:21:33.703492-04	\N	\N	1	0	0	1	1	0
75	EGRESO	PAGO EN UNA SOLA EXIBICION	1		2016-08-19	4	1	1	20	2016-08-23 13:49:22.02297-04	2016-08-23 13:52:31.850051-04	\N	1	1	0	1	1	0
61	EGRESO	PAGO EN UNA SOLA EXIBICION	1		2016-05-13	4	1	1	6	2016-08-23 12:28:27.73169-04	\N	\N	1	0	0	1	1	0
62	EGRESO	PAGO EN UNA SOLA EXIBICION	1		2016-05-20	4	1	1	7	2016-08-23 12:32:08.860923-04	\N	\N	1	0	0	1	1	0
63	EGRESO	PAGO EN UNA SOLA EXIBICION	1		2016-05-27	4	1	1	8	2016-08-23 12:34:35.300803-04	\N	\N	1	0	0	1	1	0
64	EGRESO	PAGO EN UNA SOLA EXIBICION	1		2016-06-02	4	1	1	9	2016-08-23 12:40:38.392867-04	\N	\N	1	0	0	1	1	0
65	EGRESO	PAGO EN UNA SOLA EXIBICION	1		2016-06-10	4	1	1	10	2016-08-23 12:45:02.963601-04	\N	\N	1	0	0	1	1	0
66	EGRESO	PAGO EN UNA SOLA EXIBICION	1		2016-06-17	4	1	1	11	2016-08-23 12:48:15.070174-04	\N	\N	1	0	0	1	1	0
67	EGRESO	PAGO EN UNA SOLA EXIBICION	1		2016-06-24	4	1	1	12	2016-08-23 12:50:51.267114-04	2016-08-23 12:55:16.884425-04	\N	1	1	0	1	1	0
68	EGRESO	PAGO EN UNA SOLA EXIBICION	1		2016-07-01	4	1	1	13	2016-08-23 12:57:22.271777-04	2016-08-23 13:00:58.161212-04	\N	1	1	0	1	1	0
69	EGRESO	PAGO EN UNA SOLA EXIBICION	1		2016-07-08	4	1	1	14	2016-08-23 13:05:18.764354-04	\N	\N	1	0	0	1	1	0
70	EGRESO	PAGO EN UNA SOLA EXIBICION	1		2016-07-15	4	1	1	15	2016-08-23 13:10:24.887826-04	\N	\N	1	0	0	1	1	0
71	EGRESO	PAGO EN UNA SOLA EXIBICION	1		2016-07-22	4	1	1	16	2016-08-23 13:17:56.844385-04	\N	\N	1	0	0	1	1	0
\.


--
-- Data for Name: fac_nomina_det; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY fac_nomina_det (id, fac_nomina_id, gral_empleado_id, no_empleado, rfc, nombre, curp, gral_depto_id, gral_puesto_id, fecha_contrato, antiguedad, nom_regimen_contratacion_id, nom_tipo_contrato_id, nom_tipo_jornada_id, nom_periodicidad_pago_id, clabe, tes_ban_id, nom_riesgo_puesto_id, imss, reg_patronal, salario_base, salario_integrado, fecha_ini_pago, fecha_fin_pago, no_dias_pago, concepto_descripcion, concepto_unidad, concepto_cantidad, concepto_valor_unitario, concepto_importe, descuento, motivo_descuento, gral_isr_id, importe_retencion, comp_subtotal, comp_descuento, comp_retencion, comp_total, percep_total_gravado, percep_total_excento, deduc_total_gravado, deduc_total_excento, facturado, momento_facturacion, gral_usr_id_facturacion, validado, serie, folio, ref_id, cancelado, momento_cancelacion, gral_usr_id_cancela) FROM stdin;
21	53	1	1	RIVJ830922296	JUAN ARTURO RIOS VARGAS	RIVJ830922HNLSRN06	1	1	2016-04-01	1	2	1	1	1		6	3	43008368748	D37-15870-10-0	104.519999999999996	100	2016-04-01	2016-04-07	7	PAGO DE NOMINA DEL 01/04/2016 AL 07/04/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
22	53	2					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
23	53	3					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
24	53	4					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
25	53	5					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
27	54	2					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
28	54	3					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
29	54	4					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
30	54	5					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
26	54	1	1	RIVJ830922296	JUAN ARTURO RIOS VARGAS	RIVJ830922HNLSRN06	1	1	2016-04-01	2	2	1	1	1		6	3	43008368748	D37-15870-10-0	104.519999999999996	100	2016-04-08	2016-04-14	7	PAGO DE NOMINA DEL 08/04/2016 AL 14/04/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
33	56	3					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
34	56	4					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
35	56	5					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
31	56	1	1	RIVJ830922296	JUAN ARTURO RIOS VARGAS	RIVJ830922HNLSRN06	1	1	2016-04-01	3	2	1	1	1		6	3	43008368748	D37-15870-10-0	104.519999999999996	100	2016-04-15	2016-04-21	7	PAGO DE NOMINA DEL 15/04/2016 AL 21/04/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
32	56	2	2	TAGG6107261L5	GASPAR TAMEZ GARZA	TAGG610726HNLMRS04	1	2	2016-04-15	1	2	1	1	1		6	3	43806183124	D37-15870-10-0	104.519999999999996	100	2016-04-15	2016-04-21	7	PAGO DE NOMINA DEL 15/04/2016 AL 21/04/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
38	57	3					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
39	57	4					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
40	57	5					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
37	57	2	2	TAGG6107261L5	GASPAR TAMEZ GARZA	TAGG610726HNLMRS04	1	2	2016-04-15	2	2	1	1	1		6	3	43806183124	D37-15870-10-0	104.519999999999996	100	2016-04-22	2016-04-28	7	PAGO DE NOMINA DEL 22/04/2016 AL 28/04/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
36	57	1	1	RIVJ830922296	JUAN ARTURO RIOS VARGAS	RIVJ830922HNLSRN06	1	1	2016-04-01	4	2	1	1	1		6	3	43008368748	D37-15870-10-0	104.519999999999996	100	2016-04-22	2016-04-28	7	PAGO DE NOMINA DEL 22/04/2016 AL 28/04/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
43	59	3					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
44	59	4					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
45	59	5					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
41	59	1	1	RIVJ830922296	JUAN ARTURO RIOS VARGAS	RIVJ830922HNLSRN06	1	1	2016-04-01	5	2	1	1	1		6	3	43008368748	D37-15870-10-0	104.519999999999996	100	2016-04-29	2016-05-05	7	PAGO DE NOMINA DEL 29/04/2016 AL 05/05/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
42	59	2	2	TAGG6107261L5	GASPAR TAMEZ GARZA	TAGG610726HNLMRS04	1	2	2016-04-15	3	2	1	1	1		6	3	43806183124	D37-15870-10-0	104.519999999999996	100	2016-04-29	2016-05-05	7	PAGO DE NOMINA DEL 29/04/2016 AL 05/05/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
48	61	3					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
46	61	1	1	RIVJ830922296	JUAN ARTURO RIOS VARGAS	RIVJ830922HNLSRN06	1	1	2016-04-01	6	2	1	1	1		6	3	43008368748	D37-15870-10-0	104.519999999999996	100	2016-05-06	2016-05-12	7	PAGO DE NOMINA DEL 06/05/2016 AL 12/05/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
47	61	2	2	TAGG6107261L5	GASPAR TAMEZ GARZA	TAGG610726HNLMRS04	1	2	2016-04-15	4	2	1	1	1		6	3	43806183124	D37-15870-10-0	104.519999999999996	100	2016-05-06	2016-05-12	7	PAGO DE NOMINA DEL 06/05/2016 AL 12/05/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
50	61	5					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
49	61	4	4	BARJ8707085S9	JUAN EDGAR BALBOA RIVERA	BARJ870708HNLLVN02	1	2	2016-05-05	1	2	1	1	1		6	3	43048719199	D37-15870-10-0	104.519999999999996	100	2016-05-06	2016-05-12	7	PAGO DE NOMINA DEL 06/05/2016 AL 12/05/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
53	62	3					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
55	62	5					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
51	62	1	1	RIVJ830922296	JUAN ARTURO RIOS VARGAS	RIVJ830922HNLSRN06	1	1	2016-04-01	7	2	1	1	1		6	3	43008368748	D37-15870-10-0	104.519999999999996	100	2016-05-13	2016-05-19	7	PAGO DE NOMINA DEL 13/05/2016 AL 19/05/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
52	62	2	2	TAGG6107261L5	GASPAR TAMEZ GARZA	TAGG610726HNLMRS04	1	2	2016-04-15	5	2	1	1	1		6	3	43806183124	D37-15870-10-0	104.519999999999996	100	2016-05-13	2016-05-19	7	PAGO DE NOMINA DEL 13/05/2016 AL 19/05/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
54	62	4	4	BARJ8707085S9	JUAN EDGAR BALBOA RIVERA	BARJ870708HNLLVN02	1	2	2016-05-05	2	2	1	1	1		6	3	43048719199	D37-15870-10-0	104.519999999999996	100	2016-05-13	2016-05-19	7	PAGO DE NOMINA DEL 13/05/2016 AL 19/05/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
58	63	3					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
60	63	5					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
56	63	1	1	RIVJ830922296	JUAN ARTURO RIOS VARGAS	RIVJ830922HNLSRN06	1	1	2016-04-01	8	2	1	1	1		6	3	43008368748	D37-15870-10-0	104.519999999999996	100	2016-05-20	2016-05-26	7	PAGO DE NOMINA DEL 20/05/2016 AL 26/05/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
57	63	2	2	TAGG6107261L5	GASPAR TAMEZ GARZA	TAGG610726HNLMRS04	1	2	2016-04-15	6	2	1	1	1		6	3	43806183124	D37-15870-10-0	104.519999999999996	100	2016-05-20	2016-05-26	7	PAGO DE NOMINA DEL 20/05/2016 AL 26/05/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
59	63	4	4	BARJ8707085S9	JUAN EDGAR BALBOA RIVERA	BARJ870708HNLLVN02	1	2	2016-05-05	3	2	1	1	1		6	3	43048719199	D37-15870-10-0	104.519999999999996	100	2016-05-20	2016-05-26	7	PAGO DE NOMINA DEL 20/05/2016 AL 26/05/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
63	64	3					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
65	64	5					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
61	64	1	1	RIVJ830922296	JUAN ARTURO RIOS VARGAS	RIVJ830922HNLSRN06	1	1	2016-04-01	9	2	1	1	1		6	3	43008368748	D37-15870-10-0	104.519999999999996	100	2016-05-27	2016-06-02	7	PAGO DE NOMINA DEL 27/05/2016 AL 02/06/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
62	64	2	2	TAGG6107261L5	GASPAR TAMEZ GARZA	TAGG610726HNLMRS04	1	2	2016-04-15	7	2	1	1	1		6	3	43806183124	D37-15870-10-0	104.519999999999996	100	2016-05-27	2016-06-02	7	PAGO DE NOMINA DEL 27/05/2016 AL 02/06/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
64	64	4	4	BARJ8707085S9	JUAN EDGAR BALBOA RIVERA	BARJ870708HNLLVN02	1	2	2016-05-05	4	2	1	1	1		6	3	43048719199	D37-15870-10-0	104.519999999999996	100	2016-05-27	2016-06-02	7	PAGO DE NOMINA DEL 27/05/2016 AL 02/06/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
68	65	3					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
70	65	5					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
66	65	1	1	RIVJ830922296	JUAN ARTURO RIOS VARGAS	RIVJ830922HNLSRN06	1	1	2016-04-01	10	2	1	1	1		6	3	43008368748	D37-15870-10-0	104.519999999999996	100	2016-06-03	2016-06-09	7	PAGO DE NOMINA DEL 03/06/2016 AL 09/06/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
67	65	2	2	TAGG6107261L5	GASPAR TAMEZ GARZA	TAGG610726HNLMRS04	1	2	2016-04-15	8	2	1	1	1		6	3	43806183124	D37-15870-10-0	104.519999999999996	100	2016-06-03	2016-06-09	7	PAGO DE NOMINA DEL 03/06/2016 AL 09/06/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
69	65	4	4	BARJ8707085S9	JUAN EDGAR BALBOA RIVERA	BARJ870708HNLLVN02	1	2	2016-05-05	5	2	1	1	1		6	3	43048719199	D37-15870-10-0	104.519999999999996	100	2016-06-03	2016-06-09	7	PAGO DE NOMINA DEL 03/06/2016 AL 09/06/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
73	66	3					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
75	66	5					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
71	66	1	1	RIVJ830922296	JUAN ARTURO RIOS VARGAS	RIVJ830922HNLSRN06	1	1	2016-04-01	11	2	1	1	1		6	3	43008368748	D37-15870-10-0	104.519999999999996	100	2016-06-10	2016-06-16	7	PAGO DE NOMINA DEL 10/06/2016 AL 16/06/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
72	66	2	2	TAGG6107261L5	GASPAR TAMEZ GARZA	TAGG610726HNLMRS04	1	2	2016-04-15	9	2	1	1	1		6	3	43806183124	D37-15870-10-0	104.519999999999996	100	2016-06-10	2016-06-16	7	PAGO DE NOMINA DEL 10/06/2016 AL 16/06/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
74	66	4	4	BARJ8707085S9	JUAN EDGAR BALBOA RIVERA	BARJ870708HNLLVN02	1	2	2016-05-05	6	2	1	1	1		6	3	43048719199	D37-15870-10-0	104.519999999999996	100	2016-06-10	2016-06-16	7	PAGO DE NOMINA DEL 10/06/2016 AL 16/06/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
78	67	3					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
76	67	1	1	RIVJ830922296	JUAN ARTURO RIOS VARGAS	RIVJ830922HNLSRN06	1	1	2016-04-01	12	2	1	1	1		6	3	43008368748	D37-15870-10-0	104.519999999999996	100	2016-06-17	2016-06-23	7	PAGO DE NOMINA DEL 17/06/2016 AL 23/06/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
77	67	2	2	TAGG6107261L5	GASPAR TAMEZ GARZA	TAGG610726HNLMRS04	1	2	2016-04-15	10	2	1	1	1		6	3	43806183124	D37-15870-10-0	104.519999999999996	100	2016-06-17	2016-06-23	7	PAGO DE NOMINA DEL 17/06/2016 AL 23/06/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
79	67	4	4	BARJ8707085S9	JUAN EDGAR BALBOA RIVERA	BARJ870708HNLLVN02	1	2	2016-05-05	7	2	1	1	1		6	3	43048719199	D37-15870-10-0	104.519999999999996	100	2016-06-17	2016-06-23	7	PAGO DE NOMINA DEL 17/06/2016 AL 23/06/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
84	68	4	4	BARJ8707085S9	JUAN EDGAR BALBOA RIVERA	BARJ870708HNLLVN02	1	2	2016-05-05	8	2	1	1	1		6	3	43048719199	D37-15870-10-0	104.519999999999996	100	2016-06-24	2016-06-30	7	PAGO DE NOMINA DEL 24/06/2016 AL 30/06/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
80	67	5	5	SUCA780502PG9	ALBERTO JORGE SUAREZ CAVAZOS	SUCA780502HNLRVL00	1	2	2016-06-13	1	2	1	1	1		6	3	03967836382	D37-15870-10-0	104.519999999999996	100	2016-06-17	2016-06-23	7	PAGO DE NOMINA DEL 17/06/2016 AL 23/06/2016	SERVICIO	1	1598.73000000000002	1598.73000000000002	38.5399999999999991	DEDUCCIONES DE NOMINA	1	119.010000000000005	1598.73000000000002	38.5399999999999991	119.010000000000005	1441.18000000000006	1598.73000000000002	0	0	157.550000000000011	f	\N	\N	t				f	\N	0
83	68	3					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
81	68	1	1	RIVJ830922296	JUAN ARTURO RIOS VARGAS	RIVJ830922HNLSRN06	1	1	2016-04-01	13	2	1	1	1		6	3	43008368748	D37-15870-10-0	104.519999999999996	100	2016-06-24	2016-06-30	7	PAGO DE NOMINA DEL 24/06/2016 AL 30/06/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
82	68	2	2	TAGG6107261L5	GASPAR TAMEZ GARZA	TAGG610726HNLMRS04	1	2	2016-04-15	11	2	1	1	1		6	3	43806183124	D37-15870-10-0	104.519999999999996	100	2016-06-24	2016-06-30	7	PAGO DE NOMINA DEL 24/06/2016 AL 30/06/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
86	69	1	1	RIVJ830922296	JUAN ARTURO RIOS VARGAS	RIVJ830922HNLSRN06	1	1	2016-04-01	14	2	1	1	1		6	3	43008368748	D37-15870-10-0	104.519999999999996	100	2016-07-01	2016-07-07	7	PAGO DE NOMINA DEL 01/07/2016 AL 07/07/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
85	68	5	5	SUCA780502PG9	ALBERTO JORGE SUAREZ CAVAZOS	SUCA780502HNLRVL00	1	2	2016-06-13	2	2	1	1	1		6	3	03967836382	D37-15870-10-0	104.519999999999996	100	2016-06-24	2016-06-30	7	PAGO DE NOMINA DEL 24/06/2016 AL 30/06/2016	SERVICIO	1	1598.73000000000002	1598.73000000000002	38.5399999999999991	DEDUCCIONES DE NOMINA	1	119.010000000000005	1598.73000000000002	38.5399999999999991	119.010000000000005	1441.18000000000006	1598.73000000000002	0	0	157.550000000000011	f	\N	\N	t				f	\N	0
88	69	3					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
87	69	2	2	TAGG6107261L5	GASPAR TAMEZ GARZA	TAGG610726HNLMRS04	1	2	2016-04-15	12	2	1	1	1		6	3	43806183124	D37-15870-10-0	104.519999999999996	100	2016-07-01	2016-07-07	7	PAGO DE NOMINA DEL 01/07/2016 AL 07/07/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
89	69	4	4	BARJ8707085S9	JUAN EDGAR BALBOA RIVERA	BARJ870708HNLLVN02	1	2	2016-05-05	9	2	1	1	1		6	3	43048719199	D37-15870-10-0	104.519999999999996	100	2016-07-01	2016-07-07	7	PAGO DE NOMINA DEL 01/07/2016 AL 07/07/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
90	69	5	5	SUCA780502PG9	ALBERTO JORGE SUAREZ CAVAZOS	SUCA780502HNLRVL00	1	2	2016-06-13	3	2	1	1	1		6	3	03967836382	D37-15870-10-0	104.519999999999996	100	2016-07-01	2016-07-07	7	PAGO DE NOMINA DEL 01/07/2016 AL 07/07/2016	SERVICIO	1	1598.73000000000002	1598.73000000000002	38.5399999999999991	DEDUCCIONES DE NOMINA	1	119.010000000000005	1598.73000000000002	38.5399999999999991	119.010000000000005	1441.18000000000006	1598.73000000000002	0	0	157.550000000000011	f	\N	\N	t				f	\N	0
93	70	3					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
91	70	1	1	RIVJ830922296	JUAN ARTURO RIOS VARGAS	RIVJ830922HNLSRN06	1	1	2016-04-01	15	2	1	1	1		6	3	43008368748	D37-15870-10-0	104.519999999999996	100	2016-07-08	2016-07-14	7	PAGO DE NOMINA DEL 08/07/2016 AL 14/07/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
92	70	2	2	TAGG6107261L5	GASPAR TAMEZ GARZA	TAGG610726HNLMRS04	1	2	2016-04-15	13	2	1	1	1		6	3	43806183124	D37-15870-10-0	104.519999999999996	100	2016-07-08	2016-07-14	7	PAGO DE NOMINA DEL 08/07/2016 AL 14/07/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
94	70	4	4	BARJ8707085S9	JUAN EDGAR BALBOA RIVERA	BARJ870708HNLLVN02	1	2	2016-05-05	10	2	1	1	1		6	3	43048719199	D37-15870-10-0	104.519999999999996	100	2016-07-08	2016-07-14	7	PAGO DE NOMINA DEL 08/07/2016 AL 14/07/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
95	70	5	5	SUCA780502PG9	ALBERTO JORGE SUAREZ CAVAZOS	SUCA780502HNLRVL00	1	2	2016-06-13	4	2	1	1	1		6	3	03967836382	D37-15870-10-0	104.519999999999996	100	2016-07-08	2016-07-14	7	PAGO DE NOMINA DEL 08/07/2016 AL 14/07/2016	SERVICIO	1	1598.73000000000002	1598.73000000000002	38.5399999999999991	DEDUCCIONES DE NOMINA	1	119.010000000000005	1598.73000000000002	38.5399999999999991	119.010000000000005	1441.18000000000006	1598.73000000000002	0	0	157.550000000000011	f	\N	\N	t				f	\N	0
98	71	3					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
96	71	1	1	RIVJ830922296	JUAN ARTURO RIOS VARGAS	RIVJ830922HNLSRN06	1	1	2016-04-01	16	2	1	1	1		6	3	43008368748	D37-15870-10-0	104.519999999999996	100	2016-07-15	2016-07-21	7	PAGO DE NOMINA DEL 15/07/2016 AL 21/07/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
97	71	2	2	TAGG6107261L5	GASPAR TAMEZ GARZA	TAGG610726HNLMRS04	1	2	2016-04-15	14	2	1	1	1		6	3	43806183124	D37-15870-10-0	104.519999999999996	100	2016-07-15	2016-07-21	7	PAGO DE NOMINA DEL 15/07/2016 AL 21/07/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
99	71	4	4	BARJ8707085S9	JUAN EDGAR BALBOA RIVERA	BARJ870708HNLLVN02	1	2	2016-05-05	11	2	1	1	1		6	3	43048719199	D37-15870-10-0	104.519999999999996	100	2016-07-15	2016-07-21	7	PAGO DE NOMINA DEL 15/07/2016 AL 21/07/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
100	71	5	5	SUCA780502PG9	ALBERTO JORGE SUAREZ CAVAZOS	SUCA780502HNLRVL00	1	2	2016-06-13	5	2	1	1	1		6	3	03967836382	D37-15870-10-0	104.519999999999996	100	2016-07-15	2016-07-21	7	PAGO DE NOMINA DEL 15/07/2016 AL 21/07/2016	SERVICIO	1	1598.73000000000002	1598.73000000000002	38.5399999999999991	DEDUCCIONES DE NOMINA	1	119.010000000000005	1598.73000000000002	38.5399999999999991	119.010000000000005	1441.18000000000006	1598.73000000000002	0	0	157.550000000000011	f	\N	\N	t				f	\N	0
104	72	4					0	0	\N	0	0	0	0	0		0	0			0	0	\N	\N	0			0	0	0	0		0	0	0	0	0	0	0	0	0	0	f	\N	\N	f				f	\N	0
101	72	1	1	RIVJ830922296	JUAN ARTURO RIOS VARGAS	RIVJ830922HNLSRN06	1	1	2016-04-01	17	2	1	1	1		6	3	43008368748	D37-15870-10-0	104.519999999999996	100	2016-07-22	2016-07-28	7	PAGO DE NOMINA DEL 22/07/2016 AL 28/07/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
102	72	2	2	TAGG6107261L5	GASPAR TAMEZ GARZA	TAGG610726HNLMRS04	1	2	2016-04-15	15	2	1	1	1		6	3	43806183124	D37-15870-10-0	104.519999999999996	100	2016-07-22	2016-07-28	7	PAGO DE NOMINA DEL 22/07/2016 AL 28/07/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
105	72	5	5	SUCA780502PG9	ALBERTO JORGE SUAREZ CAVAZOS	SUCA780502HNLRVL00	1	2	2016-06-13	6	2	1	1	1		6	3	03967836382	D37-15870-10-0	104.519999999999996	100	2016-07-22	2016-07-28	7	PAGO DE NOMINA DEL 22/07/2016 AL 28/07/2016	SERVICIO	1	1598.73000000000002	1598.73000000000002	38.5399999999999991	DEDUCCIONES DE NOMINA	1	119.010000000000005	1598.73000000000002	38.5399999999999991	119.010000000000005	1441.18000000000006	1598.73000000000002	0	0	157.550000000000011	f	\N	\N	t				f	\N	0
103	72	3	3	TATL820816766	JOSE LUIS TAMEZ TAMEZ	TATL820816HNLMMS07	1	2	2016-07-19	1	2	1	1	1		6	3	43038202081	D37-15870-10-0	104.519999999999996	100	2016-07-22	2016-07-28	7	PAGO DE NOMINA DEL 22/07/2016 AL 28/07/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
106	73	1	1	RIVJ830922296	JUAN ARTURO RIOS VARGAS	RIVJ830922HNLSRN06	1	1	2016-04-01	18	2	1	1	1		6	3	43008368748	D37-15870-10-0	104.519999999999996	100	2016-07-29	2016-08-04	7	PAGO DE NOMINA DEL 29/07/2016 AL 04/08/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
107	73	2	2	TAGG6107261L5	GASPAR TAMEZ GARZA	TAGG610726HNLMRS04	1	2	2016-04-15	16	2	1	1	1		6	3	43806183124	D37-15870-10-0	104.519999999999996	100	2016-07-29	2016-08-04	7	PAGO DE NOMINA DEL 29/07/2016 AL 04/08/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
109	73	4	4	BARJ8707085S9	JUAN EDGAR BALBOA RIVERA	BARJ870708HNLLVN02	1	2	2016-05-05	12	2	1	1	1		6	3	43048719199	D37-15870-10-0	104.519999999999996	100	2016-07-29	2016-08-04	7	PAGO DE NOMINA DEL 29/07/2016 AL 04/08/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
110	73	5	5	SUCA780502PG9	ALBERTO JORGE SUAREZ CAVAZOS	SUCA780502HNLRVL00	1	2	2016-06-13	7	2	1	1	1		6	3	03967836382	D37-15870-10-0	104.519999999999996	100	2016-07-29	2016-08-04	7	PAGO DE NOMINA DEL 29/07/2016 AL 04/08/2016	SERVICIO	1	1598.73000000000002	1598.73000000000002	38.5399999999999991	DEDUCCIONES DE NOMINA	1	119.010000000000005	1598.73000000000002	38.5399999999999991	119.010000000000005	1441.18000000000006	1598.73000000000002	0	0	157.550000000000011	f	\N	\N	t				f	\N	0
108	73	3	3	TATL820816766	JOSE LUIS TAMEZ TAMEZ	TATL820816HNLMMS07	1	2	2016-07-19	2	2	1	1	1		6	3	43038202081	D37-15870-10-0	104.519999999999996	100	2016-07-29	2016-08-04	7	PAGO DE NOMINA DEL 29/07/2016 AL 04/08/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
111	74	1	1	RIVJ830922296	JUAN ARTURO RIOS VARGAS	RIVJ830922HNLSRN06	1	1	2016-04-01	19	2	1	1	1		6	3	43008368748	D37-15870-10-0	104.519999999999996	100	2016-08-05	2016-08-11	7	PAGO DE NOMINA DEL 05/08/2016 AL 11/08/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
112	74	2	2	TAGG6107261L5	GASPAR TAMEZ GARZA	TAGG610726HNLMRS04	1	2	2016-04-15	17	2	1	1	1		6	3	43806183124	D37-15870-10-0	104.519999999999996	100	2016-08-05	2016-08-11	7	PAGO DE NOMINA DEL 05/08/2016 AL 11/08/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
114	74	4	4	BARJ8707085S9	JUAN EDGAR BALBOA RIVERA	BARJ870708HNLLVN02	1	2	2016-05-05	13	2	1	1	1		6	3	43048719199	D37-15870-10-0	104.519999999999996	100	2016-08-05	2016-08-11	7	PAGO DE NOMINA DEL 05/08/2016 AL 11/08/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
115	74	5	5	SUCA780502PG9	ALBERTO JORGE SUAREZ CAVAZOS	SUCA780502HNLRVL00	1	2	2016-06-13	8	2	1	1	1		6	3	03967836382	D37-15870-10-0	104.519999999999996	100	2016-08-05	2016-08-11	7	PAGO DE NOMINA DEL 05/08/2016 AL 11/08/2016	SERVICIO	1	1598.73000000000002	1598.73000000000002	38.5399999999999991	DEDUCCIONES DE NOMINA	1	119.010000000000005	1598.73000000000002	38.5399999999999991	119.010000000000005	1441.18000000000006	1598.73000000000002	0	0	157.550000000000011	f	\N	\N	t				f	\N	0
113	74	3	3	TATL820816766	JOSE LUIS TAMEZ TAMEZ	TATL820816HNLMMS07	1	2	2016-07-19	3	2	1	1	1		6	3	43038202081	D37-15870-10-0	104.519999999999996	100	2016-08-05	2016-08-11	7	PAGO DE NOMINA DEL 05/08/2016 AL 11/08/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
116	75	1	1	RIVJ830922296	JUAN ARTURO RIOS VARGAS	RIVJ830922HNLSRN06	1	1	2016-04-01	20	2	1	1	1		6	3	43008368748	D37-15870-10-0	104.519999999999996	100	2016-08-12	2016-08-18	7	PAGO DE NOMINA DEL 12/08/2016 AL 18/08/2016	SERVICIO	1	793.600000000000023	793.600000000000023	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.600000000000023	17.379999999999999	39.6599999999999966	736.559999999999945	793.600000000000023	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
117	75	2	2	TAGG6107261L5	GASPAR TAMEZ GARZA	TAGG610726HNLMRS04	1	2	2016-04-15	18	2	1	1	1		6	3	43806183124	D37-15870-10-0	104.519999999999996	100	2016-08-12	2016-08-18	7	PAGO DE NOMINA DEL 12/08/2016 AL 18/08/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
119	75	4	4	BARJ8707085S9	JUAN EDGAR BALBOA RIVERA	BARJ870708HNLLVN02	1	2	2016-05-05	14	2	1	1	1		6	3	43048719199	D37-15870-10-0	104.519999999999996	100	2016-08-12	2016-08-18	7	PAGO DE NOMINA DEL 12/08/2016 AL 18/08/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
120	75	5	5	SUCA780502PG9	ALBERTO JORGE SUAREZ CAVAZOS	SUCA780502HNLRVL00	1	2	2016-06-13	9	2	1	1	1		6	3	03967836382	D37-15870-10-0	104.519999999999996	100	2016-08-12	2016-08-18	7	PAGO DE NOMINA DEL 12/08/2016 AL 18/08/2016	SERVICIO	1	1598.73000000000002	1598.73000000000002	38.5399999999999991	DEDUCCIONES DE NOMINA	1	119.010000000000005	1598.73000000000002	38.5399999999999991	119.010000000000005	1441.18000000000006	1598.73000000000002	0	0	157.550000000000011	f	\N	\N	t				f	\N	0
118	75	3	3	TATL820816766	JOSE LUIS TAMEZ TAMEZ	TATL820816HNLMMS07	1	2	2016-07-19	4	2	1	1	1		6	3	43038202081	D37-15870-10-0	104.519999999999996	100	2016-08-12	2016-08-18	7	PAGO DE NOMINA DEL 12/08/2016 AL 18/08/2016	SERVICIO	1	793.659999999999968	793.659999999999968	17.379999999999999	DEDUCCIONES DE NOMINA	1	39.6599999999999966	793.659999999999968	17.379999999999999	39.6599999999999966	736.620000000000005	793.659999999999968	0	0	57.0399999999999991	f	\N	\N	t				f	\N	0
\.


--
-- Data for Name: fac_nomina_det_deduc; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY fac_nomina_det_deduc (id, fac_nomina_det_id, nom_deduc_id, gravado, excento) FROM stdin;
21	11	1	17.379999999999999	0
22	11	2	39.6599999999999966	0
23	16	1	0	17.379999999999999
24	16	2	0	39.6599999999999966
25	26	1	0	17.379999999999999
26	26	2	0	39.6599999999999966
27	31	1	0	17.379999999999999
28	31	2	0	39.6599999999999966
29	32	1	0	17.379999999999999
30	32	2	0	39.6599999999999966
31	37	1	0	17.379999999999999
32	37	2	0	39.6599999999999966
33	36	1	0	17.379999999999999
34	36	2	0	39.6599999999999966
35	21	1	0	17.379999999999999
36	21	2	0	39.6599999999999966
37	41	1	0	17.379999999999999
38	41	2	0	39.6599999999999966
39	42	1	0	17.379999999999999
40	42	2	0	39.6599999999999966
41	46	1	0	17.379999999999999
42	46	2	0	39.6599999999999966
43	47	1	0	17.379999999999999
44	47	2	0	39.6599999999999966
45	49	1	0	17.379999999999999
46	49	2	0	39.6599999999999966
47	51	1	0	17.379999999999999
48	51	2	0	39.6599999999999966
49	52	1	0	17.379999999999999
50	52	2	0	39.6599999999999966
51	54	1	0	17.379999999999999
52	54	2	0	39.6599999999999966
53	56	1	0	17.379999999999999
54	56	2	0	39.6599999999999966
55	57	1	0	17.379999999999999
56	57	2	0	39.6599999999999966
57	59	1	0	17.379999999999999
58	59	2	0	39.6599999999999966
59	61	1	0	17.379999999999999
60	61	2	0	39.6599999999999966
61	62	1	0	17.379999999999999
62	62	2	0	39.6599999999999966
63	64	1	0	17.379999999999999
64	64	2	0	39.6599999999999966
65	66	1	0	17.379999999999999
66	66	2	0	39.6599999999999966
67	67	1	0	17.379999999999999
68	67	2	0	39.6599999999999966
69	69	1	0	17.379999999999999
70	69	2	0	39.6599999999999966
71	71	1	0	17.379999999999999
72	71	2	0	39.6599999999999966
73	72	1	0	17.379999999999999
74	72	2	0	39.6599999999999966
75	74	1	0	17.379999999999999
76	74	2	0	39.6599999999999966
77	76	1	0	17.379999999999999
78	76	2	0	39.6599999999999966
79	77	1	0	17.379999999999999
80	77	2	0	39.6599999999999966
81	79	1	0	17.379999999999999
82	79	2	0	39.6599999999999966
86	80	1	0	38.5399999999999991
87	80	2	0	119.010000000000005
88	81	1	0	17.379999999999999
89	81	2	0	39.6599999999999966
90	82	1	0	17.379999999999999
91	82	2	0	39.6599999999999966
92	84	1	0	17.379999999999999
93	84	2	0	39.6599999999999966
96	85	1	0	38.5399999999999991
97	85	2	0	119.010000000000005
98	86	1	0	17.379999999999999
99	86	2	0	39.6599999999999966
100	87	1	0	17.379999999999999
101	87	2	0	39.6599999999999966
102	89	1	0	17.379999999999999
103	89	2	0	39.6599999999999966
106	90	1	0	38.5399999999999991
107	90	2	0	119.010000000000005
108	91	1	0	17.379999999999999
109	91	2	0	39.6599999999999966
110	92	1	0	17.379999999999999
111	92	2	0	39.6599999999999966
112	94	1	0	17.379999999999999
113	94	2	0	39.6599999999999966
114	95	1	0	38.5399999999999991
115	95	2	0	119.010000000000005
116	96	1	0	17.379999999999999
117	96	2	0	39.6599999999999966
118	97	1	0	17.379999999999999
119	97	2	0	39.6599999999999966
120	99	1	0	17.379999999999999
121	99	2	0	39.6599999999999966
122	100	1	0	38.5399999999999991
123	100	2	0	119.010000000000005
124	101	1	0	17.379999999999999
125	101	2	0	39.6599999999999966
126	102	1	0	17.379999999999999
127	102	2	0	39.6599999999999966
128	105	1	0	38.5399999999999991
129	105	2	0	119.010000000000005
130	103	1	0	17.379999999999999
131	103	2	0	39.6599999999999966
132	106	1	0	17.379999999999999
133	106	2	0	39.6599999999999966
134	107	1	0	17.379999999999999
135	107	2	0	39.6599999999999966
136	109	1	0	17.379999999999999
137	109	2	0	39.6599999999999966
138	110	1	0	38.5399999999999991
139	110	2	0	119.010000000000005
140	108	1	0	17.379999999999999
141	108	2	0	39.6599999999999966
142	111	1	0	17.379999999999999
143	111	2	0	39.6599999999999966
144	112	1	0	17.379999999999999
145	112	2	0	39.6599999999999966
146	114	1	0	17.379999999999999
147	114	2	0	39.6599999999999966
148	115	1	0	38.5399999999999991
149	115	2	0	119.010000000000005
150	113	1	0	17.379999999999999
151	113	2	0	39.6599999999999966
152	116	1	0	17.379999999999999
153	116	2	0	39.6599999999999966
154	117	1	0	17.379999999999999
155	117	2	0	39.6599999999999966
156	119	1	0	17.379999999999999
157	119	2	0	39.6599999999999966
158	120	1	0	38.5399999999999991
159	120	2	0	119.010000000000005
160	118	1	0	17.379999999999999
161	118	2	0	39.6599999999999966
\.


--
-- Name: fac_nomina_det_deduc_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('fac_nomina_det_deduc_id_seq', 161, true);


--
-- Data for Name: fac_nomina_det_hrs_extra; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY fac_nomina_det_hrs_extra (id, fac_nomina_det_id, nom_tipo_hrs_extra_id, no_dias, no_hrs, importe) FROM stdin;
\.


--
-- Name: fac_nomina_det_hrs_extra_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('fac_nomina_det_hrs_extra_id_seq', 1, false);


--
-- Name: fac_nomina_det_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('fac_nomina_det_id_seq', 120, true);


--
-- Data for Name: fac_nomina_det_incapa; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY fac_nomina_det_incapa (id, fac_nomina_det_id, nom_tipo_incapacidad_id, no_dias, importe) FROM stdin;
\.


--
-- Name: fac_nomina_det_incapa_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('fac_nomina_det_incapa_id_seq', 1, false);


--
-- Data for Name: fac_nomina_det_percep; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY fac_nomina_det_percep (id, fac_nomina_det_id, nom_percep_id, gravado, excento) FROM stdin;
1	6	1	700	0
2	6	8	93.6599999999999966	0
23	11	1	700	0
24	11	8	93.6599999999999966	0
25	16	1	700	0
26	16	8	93.6599999999999966	0
27	26	1	700	0
28	26	8	93.6599999999999966	0
29	31	1	700	0
30	31	8	93.6599999999999966	0
31	32	1	700	0
32	32	8	93.6599999999999966	0
33	37	1	700	0
34	37	8	93.6599999999999966	0
35	36	1	700	0
36	36	8	93.6599999999999966	0
37	21	1	700	0
38	21	8	93.6599999999999966	0
39	41	1	700	0
40	41	8	93.6599999999999966	0
41	42	1	700	0
42	42	8	93.6599999999999966	0
43	46	1	700	0
44	46	8	93.6599999999999966	0
45	47	1	700	0
46	47	8	93.6599999999999966	0
47	49	1	700	0
48	49	8	93.6599999999999966	0
49	51	1	700	0
50	51	8	93.6599999999999966	0
51	52	1	700	0
52	52	8	93.6599999999999966	0
53	54	1	700	0
54	54	8	93.6599999999999966	0
55	56	1	700	0
56	56	8	93.6599999999999966	0
57	57	1	700	0
58	57	8	93.6599999999999966	0
59	59	1	700	0
60	59	8	93.6599999999999966	0
61	61	1	700	0
62	61	8	93.6599999999999966	0
63	62	1	700	0
64	62	8	93.6599999999999966	0
65	64	1	700	0
66	64	8	93.6599999999999966	0
67	66	1	700	0
68	66	8	93.6599999999999966	0
69	67	1	700	0
70	67	8	93.6599999999999966	0
71	69	1	700	0
72	69	8	93.6599999999999966	0
73	71	1	700	0
74	71	8	93.6599999999999966	0
75	72	1	700	0
76	72	8	93.6599999999999966	0
77	74	1	700	0
78	74	8	93.6599999999999966	0
79	76	1	700	0
80	76	8	93.6599999999999966	0
81	77	1	700	0
82	77	8	93.6599999999999966	0
83	79	1	700	0
84	79	8	93.6599999999999966	0
87	80	1	1540.34999999999991	0
88	80	8	58.3800000000000026	0
89	81	1	700	0
90	81	8	93.6599999999999966	0
91	82	1	700	0
92	82	8	93.6599999999999966	0
93	84	1	700	0
94	84	8	93.6599999999999966	0
97	85	1	1540.34999999999991	0
98	85	8	58.3800000000000026	0
99	86	1	700	0
100	86	8	93.6599999999999966	0
101	87	1	700	0
102	87	8	93.6599999999999966	0
103	89	1	700	0
104	89	8	93.6599999999999966	0
107	90	1	1540.34999999999991	0
108	90	8	58.3800000000000026	0
109	91	1	700	0
110	91	8	93.6599999999999966	0
111	92	1	700	0
112	92	8	93.6599999999999966	0
113	94	1	700	0
114	94	8	93.6599999999999966	0
115	95	1	1540.34999999999991	0
116	95	8	58.3800000000000026	0
117	96	1	700	0
118	96	8	93.6599999999999966	0
119	97	1	700	0
120	97	8	93.6599999999999966	0
121	99	1	700	0
122	99	8	93.6599999999999966	0
123	100	1	1540.34999999999991	0
124	100	8	58.3800000000000026	0
125	101	1	700	0
126	101	8	93.6599999999999966	0
127	102	1	700	0
128	102	8	93.6599999999999966	0
129	105	1	1540.34999999999991	0
130	105	8	58.3800000000000026	0
131	103	1	700	0
132	103	8	93.6599999999999966	0
133	106	1	700	0
134	106	8	93.6599999999999966	0
135	107	1	700	0
136	107	8	93.6599999999999966	0
137	109	1	700	0
138	109	8	93.6599999999999966	0
139	110	1	1540.34999999999991	0
140	110	8	58.3800000000000026	0
141	108	1	700	0
142	108	8	93.6599999999999966	0
143	111	1	700	0
144	111	8	93.6599999999999966	0
145	112	1	700	0
146	112	8	93.6599999999999966	0
147	114	1	700	0
148	114	8	93.6599999999999966	0
149	115	1	1540.34999999999991	0
150	115	8	58.3800000000000026	0
151	113	1	700	0
152	113	8	93.6599999999999966	0
153	116	1	700	0
154	116	8	93.5999999999999943	0
155	117	1	700	0
156	117	8	93.6599999999999966	0
157	119	1	700	0
158	119	8	93.6599999999999966	0
159	120	1	1540.34999999999991	0
160	120	8	58.3800000000000026	0
161	118	1	700	0
162	118	8	93.6599999999999966	0
\.


--
-- Name: fac_nomina_det_percep_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('fac_nomina_det_percep_id_seq', 162, true);


--
-- Name: fac_nomina_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('fac_nomina_id_seq', 75, true);


--
-- Data for Name: fac_nomina_par; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY fac_nomina_par (id, gral_emp_id, gral_suc_id, tipo_comprobante, forma_pago, no_cuenta_pago, gral_mon_id, gral_isr_id, motivo_descuento, concepto_unidad, leyenda) FROM stdin;
1	1	1	EGRESO	PAGO EN UNA SOLA EXIBICION		1	1	DEDUCCIONES DE NOMINA	SERVICIO	Recibí de "x" la cantidad especificada como neto a pagar por concepto de mí sueldo y demas prestaciones correspondientes al periodo indicado. Estando conforme con las deducciones aplicadas. Ademas certifico que a la fecha no se me adeuda ninguna cantidad por ningun concepto relacionado con el desarrollo de mí trabajo.
\.


--
-- Name: fac_nomina_par_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('fac_nomina_par_id_seq', 1, false);


--
-- Data for Name: fac_par; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY fac_par (id, gral_suc_id, cxc_mov_tipo_id, inv_alm_id, permitir_pedido, permitir_remision, permitir_cambio_almacen, permitir_servicios, permitir_articulos, permitir_kits, gral_suc_id_consecutivo, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja, gral_emp_id, formato_pedido, formato_factura, validar_pres_pedido, cambiar_unidad_medida, incluye_adenda, gral_emails_id_envio, gral_emails_id_cco, permitir_descto, permitir_req_com, aut_precio_menor_cot, aut_precio_menor_ped) FROM stdin;
1	1	1	1	t	t	t	t	t	t	1	f	2015-06-08 20:00:00-04	2016-03-09 07:18:26.349635-05	\N	0	1	0	1	1	1	f	t	f	1	1	f	f	f	f
\.


--
-- Name: fac_par_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('fac_par_id_seq', 1, false);


--
-- Data for Name: gral_app; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_app (id, descripcion, nombre_app, tipo) FROM stdin;
4	Catalogo de Empleados	\N	\N
\.


--
-- Name: gral_app_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_app_id_seq', 1, false);


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
-- Data for Name: gral_cons; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_cons (id, gral_emp_id, gral_suc_id, gral_cons_tipo_id, prefijo, consecutivo, borrado_logico) FROM stdin;
66	1	1	15		0	f
\.


--
-- Name: gral_cons_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_cons_id_seq', 1, false);


--
-- Data for Name: gral_cons_tipos; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_cons_tipos (id, titulo, borrado_logico) FROM stdin;
1	Numero de control de clientes	f
2	Folio de proveedores	f
3	Folio codigo de producto	f
4	Folio entrada de mercancia	f
5	Folio cotizaciones	f
6	Folio orden de compra	f
7	Folio pedidos	f
8	Folio pagos a proveedores	f
9	Folio anticipos a proveedores	f
10	Folio Remision	f
11	Numero transaccion pagos CXC	f
13	Folio Programacion Ruta	f
14	Folio Configuracion Produccion	f
15	Clave del Empleado	f
16	Folio Entrada de Mercancia	f
17	Folio Orden de Entrada	f
12	Folio Asignacion de rutas	f
18	Folio Preorden de Produccion	f
19	Folio Orden Compra	f
20	Folio Orden Produccion	f
21	Folio Orden de Salida	f
22	Folio Ajuste de Inventario	f
23	Folio Requisicion de produccion	f
24	Folio backorder(tabla poc_ped_detalle)	f
25	Consecutivo Numero de Lote	f
26	Folio Orden de Devolucion	f
27	Folio Impresion de Etiquetas	f
28	Folio registro Notas de Credito Proveedores	f
29	Folio Traspaso	f
30	Folio Orden de Traspaso	f
31	Folio produccion de Sub-Ensamble	f
32	Folio Requisicion	f
33	Folio Catalogo Motivos Visita	f
34	Folio Catalogo Formas Contacto	f
35	Folio Catalogo Motivos Llamadas	f
36	Folio Registro Visitas(CRM)	f
37	Registro de Lamadas(CRM)	f
38	Folio Catalogo de Prospectos(CRM)	f
39	Folio Catalogo de Contactos(CRM)	f
40	Folio Registro de Metas(CRM)	f
41	Folio Registro Casos(CRM)	f
42	Folio Proceso de Re-Envasado	f
43	Folio Proceso de Envasado	f
44	Folio Catalogo de Remitentes	f
45	Folio Catalogo de Destinatarios	f
46	Folio Catalogo de Agentes Aduanales	f
47	Folio Catalogo de Operadores	f
48	Folio Catalogo de Percepciones	f
49	Folio Catalogo de Deducciones	f
50	Numero de Poliza Contable	f
51	Folio carga de documento(LOG)	f
\.


--
-- Name: gral_cons_tipos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_cons_tipos_id_seq', 1, false);


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
-- Data for Name: gral_deptos_turnos; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_deptos_turnos (id, gral_deptos_id, turno, hora_ini, hora_fin, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja, gral_emp_id, gral_suc_id) FROM stdin;
1	1	1	08:00:00-06	18:00:00-06	f	2012-11-24 17:25:43.85546-05	\N	\N	1	0	0	1	1
\.


--
-- Name: gral_deptos_turnos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_deptos_turnos_id_seq', 1, false);


--
-- Data for Name: gral_dias_no_laborables; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_dias_no_laborables (id, fecha_no_laborable, descripcion, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja, gral_emp_id, gral_suc_id) FROM stdin;
1	2013-01-01	AÑO NUEVO	f	2012-11-24 17:20:56.075953-05	2012-11-24 17:21:05.261925-05	\N	1	1	0	1	1
\.


--
-- Name: gral_dias_no_laborables_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_dias_no_laborables_id_seq', 1, false);


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
9	Ciudad de México	CDMX	2
33	Texas	TX	1
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
1	EXPORTACIONES SUMAR S.A. DE C.V.	CENTRO	64000	ISAAC GARZA	ESU131122SZ6	1810	\N	2016-08-10 00:00:00-04	2016-08-10 00:00:00-04	\N	8112345678	f	19	986	2	REGIMEN GENERAL DE LEY PERSONAS MORALES	f			www.exportacionessumar.com	f	5	f	f	t	f	cfditf	2	f	1	f	4	t	1	f	0
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
-- Data for Name: gral_empleado_deduc; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_empleado_deduc (id, gral_empleado_id, nom_deduc_id) FROM stdin;
41	1	1
42	1	2
43	2	1
44	2	2
45	3	1
46	3	2
49	4	1
50	4	2
53	5	1
54	5	2
\.


--
-- Name: gral_empleado_deduc_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_empleado_deduc_id_seq', 54, true);


--
-- Data for Name: gral_empleado_percep; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_empleado_percep (id, gral_empleado_id, nom_percep_id) FROM stdin;
41	1	1
42	1	8
43	2	1
44	2	8
45	3	1
46	3	8
49	4	1
50	4	8
53	5	1
54	5	8
\.


--
-- Name: gral_empleado_percep_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_empleado_percep_id_seq', 54, true);


--
-- Data for Name: gral_empleados; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_empleados (id, clave, nombre_pila, apellido_paterno, apellido_materno, imss, infonavit, curp, rfc, fecha_nacimiento, fecha_ingreso, gral_escolaridad_id, gral_sexo_id, gral_civil_id, gral_religion_id, gral_sangretipo_id, gral_puesto_id, gral_categ_id, gral_suc_id_empleado, telefono, telefono_movil, correo_personal, gral_pais_id, gral_edo_id, gral_mun_id, calle, numero, colonia, cp, contacto_emergencia, telefono_emergencia, enfermedades, alergias, comentarios, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja, gral_emp_id, gralsuc_id, comision_agen, region_id_agen, comision2_agen, comision3_agen, comision4_agen, dias_tope_comision, dias_tope_comision2, dias_tope_comision3, monto_tope_comision, monto_tope_comision2, monto_tope_comision3, correo_empresa, tipo_comision, no_int, nom_regimen_contratacion_id, nom_periodicidad_pago_id, nom_riesgo_puesto_id, nom_tipo_contrato_id, nom_tipo_jornada_id, tes_ban_id, clabe, salario_base, salario_integrado, registro_patronal, genera_nomina, gral_depto_id) FROM stdin;
1	1	JUAN ARTURO	RIOS	VARGAS	43008368748		RIVJ830922HNLSRN06	RIVJ830922296	1983-09-22	2016-04-01	3	1	2	1	1	1	1	1				2	19	951										f	\N	2016-08-20 21:23:50.169162-04	\N	1	1	1	1	1	0	1	0	0	0	0	0	0	0	0	0		1		2	1	3	1	1	6		104.519999999999996	100	D37-15870-10-0	t	1
2	2	GASPAR	TAMEZ	GARZA	43806183124		TAGG610726HNLMRS04	TAGG6107261L5	1961-07-26	2016-04-15	3	1	2	1	1	2	2	1				2	19	951										f	\N	2016-08-20 21:23:56.210519-04	\N	1	1	1	1	1	0	1	0	0	0	0	0	0	0	0	0		1		2	1	3	1	1	6		104.519999999999996	100	D37-15870-10-0	t	1
3	3	JOSE LUIS	TAMEZ	TAMEZ	43038202081		TATL820816HNLMMS07	TATL820816766	1982-08-16	2016-07-19	3	1	2	1	1	2	0	1				2	19	951										f	\N	2016-08-20 21:24:00.778474-04	\N	1	1	1	1	1	0	1	0	0	0	0	0	0	0	0	0		1		2	1	3	1	1	6		104.519999999999996	100	D37-15870-10-0	t	1
4	4	JUAN EDGAR	BALBOA	RIVERA	43048719199		BARJ870708HNLLVN02	BARJ8707085S9	1987-07-08	2016-05-05	3	1	2	1	1	2	0	1				2	19	951										f	\N	2016-08-20 21:24:12.695887-04	\N	1	1	1	1	1	0	1	0	0	0	0	0	0	0	0	0		1		2	1	3	1	1	6		104.519999999999996	100	D37-15870-10-0	t	1
5	5	ALBERTO JORGE	SUAREZ	CAVAZOS	03967836382		SUCA780502HNLRVL00	SUCA780502PG9	1978-05-02	2016-06-13	3	1	2	1	1	2	0	1				2	19	951										f	\N	2016-08-23 12:54:44.480675-04	\N	1	1	1	1	1	0	1	0	0	0	0	0	0	0	0	0		1		2	1	3	1	1	6		104.519999999999996	100	D37-15870-10-0	t	1
\.


--
-- Name: gral_empleados_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_empleados_id_seq', 6, true);


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
-- Data for Name: gral_ieps; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_ieps (id, titulo, descripcion, tasa, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_usr_id_crea, gral_usr_id_actualiza, gral_usr_id_cancela, gral_emp_id, gral_suc_id) FROM stdin;
2	3%		3	f	2014-10-24 05:59:02.667882-04	2014-10-24 06:45:24.010261-04	\N	37	37	0	1	1
1	4.5		4.5	f	2014-10-24 05:47:55.642783-04	2014-10-24 06:45:39.422769-04	\N	37	37	0	1	1
\.


--
-- Name: gral_ieps_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_ieps_id_seq', 1, false);


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
-- Data for Name: gral_imptos_ret; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_imptos_ret (id, titulo, descripcion, tasa, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_usr_id_crea, gral_usr_id_actualiza, gral_usr_id_cancela, gral_emp_id, gral_suc_id) FROM stdin;
\.


--
-- Name: gral_imptos_ret_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_imptos_ret_id_seq', 1, false);


--
-- Data for Name: gral_isr; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_isr (id, titulo, descripcion, tasa, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_usr_id_crea, gral_usr_id_actualiza, gral_usr_id_cancela, gral_emp_id, gral_suc_id) FROM stdin;
1	ISR	IMPUESTO SOBRE LA RENTA	0	f	2014-03-04 01:00:00-05	\N	\N	1	0	0	1	1
\.


--
-- Name: gral_isr_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_isr_id_seq', 1, false);


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
San Juan	33	1	2457
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
-- Data for Name: gral_plazas; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_plazas (titulo, descripcion, momento_creacion, momento_actualizacion, momento_baja, borrado_logico, id, empresa_id, inv_zonas_id, estatus) FROM stdin;
MTY	MONTERREY	2012-05-25 10:35:07.3087-04	\N	2012-05-25 10:36:02.812795-04	f	1	1	1	t
\.


--
-- Name: gral_plazas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_plazas_id_seq', 1, false);


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
-- Data for Name: gral_reg; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_reg (id, titulo, borrado_logico) FROM stdin;
1	REGION_A	f
\.


--
-- Name: gral_reg_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_reg_id_seq', 2, true);


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
1	ALLENDE	64000	CENTRO	ISAAC GARZA	\N	1810	f	1	2016-08-11 00:00:00-04	2016-08-11 00:00:00-04	\N	2	19	986	1	sumar@exportacionessumar.com	MTY
\.


--
-- Name: gral_suc_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_suc_id_seq', 1, true);


--
-- Data for Name: gral_suc_pza; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_suc_pza (id, plaza_id, sucursal_id) FROM stdin;
1	1	1
\.


--
-- Name: gral_suc_pza_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_suc_pza_id_seq', 1, false);


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
1	admin	123qwe	t	2016-08-23 20:56:01.693472-04	1
2	admin1	123qwe	t	\N	2
3	admin2	123qwe	t	\N	3
4	admin3	123qwe	t	\N	4
5	admin4	123qwe	f	\N	5
\.


--
-- Name: gral_usr_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_usr_id_seq', 4, true);


--
-- Data for Name: gral_usr_rol; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_usr_rol (id, gral_usr_id, gral_rol_id) FROM stdin;
30	1	1
31	2	1
32	3	1
34	4	1
36	5	1
\.


--
-- Name: gral_usr_rol_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_usr_rol_id_seq', 36, true);


--
-- Data for Name: gral_usr_suc; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY gral_usr_suc (id, gral_usr_id, gral_suc_id) FROM stdin;
1	1	1
2	2	1
3	3	1
4	4	1
5	5	1
\.


--
-- Name: gral_usr_suc_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('gral_usr_suc_id_seq', 5, true);


--
-- Data for Name: inv_alm; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY inv_alm (id, titulo, borrado_logico, calle, colonia, numero, codigo_postal, almacen_tipo_id, momento_creacion, momento_actualizacion, momento_baja, gral_pais_id, gral_edo_id, gral_mun_id, reporteo, ventas, compras, reabastecimiento, garantias, consignacion, recepcion_mat, explosion_mat, responsable, responsable_email, responsable_puesto, tel_1_ext, tel_2_ext, tel_2, tel_1, traspaso) FROM stdin;
1	ALMACEN GUDALUPE	f	ARTURO B. DE LA GARZA	LOS LERMAS	223	23456	1	2011-07-25 16:30:24.337871-04	2014-08-18 12:56:06.990255-04	\N	2	19	973	t	t	t	t	t	t	t	t	JOSE FRANCISCO CASTILLO NIETO		OPERARIO				8183605945	t
\.


--
-- Name: inv_alm_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('inv_alm_id_seq', 1, false);


--
-- Data for Name: inv_alm_tipos; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY inv_alm_tipos (id, titulo) FROM stdin;
1	FISICO
2	CONSIGNACION
3	VIRTUAL
\.


--
-- Name: inv_alm_tipos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('inv_alm_tipos_id_seq', 1, false);


--
-- Data for Name: inv_clas; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY inv_clas (id, titulo, stock_seguridad, factor_maximo, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_emp_id, gral_suc_id, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja, descripcion) FROM stdin;
1	CLASE 1	0	0	f	2012-06-27 20:00:00-04	2012-06-11 20:00:00-04	\N	1	1	1	1	0	CLASE 1
\.


--
-- Name: inv_clas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('inv_clas_id_seq', 1, false);


--
-- Data for Name: inv_exi; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY inv_exi (id, inv_prod_id, inv_alm_id, ano, transito, reservado, exi_inicial, entradas_1, salidas_1, costo_ultimo_1, entradas_2, salidas_2, costo_ultimo_2, entradas_3, salidas_3, costo_ultimo_3, entradas_4, salidas_4, costo_ultimo_4, entradas_5, salidas_5, costo_ultimo_5, entradas_6, salidas_6, costo_ultimo_6, entradas_7, salidas_7, costo_ultimo_7, entradas_8, salidas_8, costo_ultimo_8, entradas_9, salidas_9, costo_ultimo_9, entradas_10, salidas_10, costo_ultimo_10, entradas_11, salidas_11, costo_ultimo_11, entradas_12, salidas_12, costo_ultimo_12, momento_entrada_1, momento_salida_1, momento_entrada_2, momento_salida_2, momento_entrada_3, momento_salida_3, momento_entrada_4, momento_salida_4, momento_entrada_5, momento_salida_5, momento_entrada_6, momento_salida_6, momento_entrada_7, momento_salida_7, momento_entrada_8, momento_salida_8, momento_entrada_9, momento_salida_9, momento_entrada_10, momento_salida_10, momento_entrada_11, momento_salida_11, momento_entrada_12, momento_salida_12) FROM stdin;
3	8	1	2016	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
\.


--
-- Name: inv_exi_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('inv_exi_id_seq', 3, true);


--
-- Data for Name: inv_kit; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY inv_kit (id, producto_kit_id, cantidad, producto_elemento_id) FROM stdin;
\.


--
-- Name: inv_kit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('inv_kit_id_seq', 1, false);


--
-- Data for Name: inv_mar; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY inv_mar (id, titulo, url, estatus, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_emp_id, gral_suc_id, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja) FROM stdin;
1	COCA COLA	http://www.agnux.com	t	f	2016-08-13 00:00:00-04	\N	\N	1	1	1	0	0
2	PEPSI	\N	t	f	2016-08-13 00:00:00-04	\N	\N	1	1	1	0	0
3	JOYA	\N	t	f	2016-08-13 00:00:00-04	\N	\N	1	1	1	0	0
\.


--
-- Name: inv_mar_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('inv_mar_id_seq', 1, false);


--
-- Data for Name: inv_mov_tipos; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY inv_mov_tipos (id, titulo, descripcion, momento_creacion, momento_baja, momento_actualizacion, borrado_logico, grupo, afecta_compras, afecta_ventas, considera_consumo, tipo_costo, ajuste) FROM stdin;
9	CANCELACION DE ENTRADA	SALIDA POR CANCELACION DE ENTRADA	2012-06-07 17:28:51.903-04	\N	\N	f	2	t	t	f	0	f
1	COMPRA	ENTRADA POR COMPRA	2012-06-07 17:23:03.225555-04	\N	\N	f	0	t	t	f	0	f
5	VENTA	SALIDA POR VENTA	2012-06-07 17:27:08.319952-04	\N	2012-06-21 12:29:05.043876-04	f	2	f	t	f	0	f
2	DEV CANCELACION DE FACTURA	DEVOLUCION POR CANCELACION DE FACTURA	2012-06-07 17:25:14.708636-04	\N	\N	f	0	t	t	f	0	f
21	DEVOLUCION DE MERCANCIA	DEVOLUCION DE MERCANCIA CON NOTA DE CREDITO	\N	\N	\N	f	0	f	f	f	2	f
22	DEV CANCELACION DE REMISION	DEVOLUCION POR CANCELACION DE REMISION	\N	\N	\N	f	0	f	f	f	2	f
8	SALIDA AJUSTE	SALIDA POR AJUSTE INVENTARIO FISICO	2012-06-07 17:28:51.903-04	\N	2015-06-09 09:55:04.748813-04	f	2	f	t	t	0	t
4	ENTRADA AJUSTE	ENTRADA POR AJUSTE INVENTARIO FISICO	2012-06-07 17:26:32.146435-04	\N	2015-06-09 09:55:21.022722-04	f	0	f	t	t	0	t
\.


--
-- Name: inv_mov_tipos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('inv_mov_tipos_id_seq', 1, false);


--
-- Data for Name: inv_pre; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY inv_pre (id, inv_prod_id, precio_1, precio_2, precio_3, precio_4, precio_5, precio_6, precio_7, precio_8, precio_9, precio_10, descuento_1, descuento_2, descuento_3, descuento_4, descuento_5, descuento_6, descuento_7, descuento_8, descuento_9, descuento_10, base_precio_1, base_precio_2, base_precio_3, base_precio_4, base_precio_5, base_precio_6, base_precio_7, base_precio_8, base_precio_9, base_precio_10, default_precio_1, default_precio_2, default_precio_3, default_precio_4, default_precio_5, default_precio_6, default_precio_7, default_precio_8, default_precio_9, default_precio_10, operacion_precio_1, operacion_precio_2, operacion_precio_3, operacion_precio_4, operacion_precio_5, operacion_precio_6, operacion_precio_7, operacion_precio_8, operacion_precio_9, operacion_precio_10, calculo_precio_1, calculo_precio_2, calculo_precio_3, calculo_precio_4, calculo_precio_5, calculo_precio_6, calculo_precio_7, calculo_precio_8, calculo_precio_9, calculo_precio_10, redondeo_precio_1, redondeo_precio_2, redondeo_precio_3, redondeo_precio_4, redondeo_precio_5, redondeo_precio_6, redondeo_precio_7, redondeo_precio_8, redondeo_precio_9, redondeo_precio_10, gral_emp_id, borrado_logico, momento_creacion, momento_baja, momento_actualizacion, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja, gral_mon_id_pre1, gral_mon_id_pre2, gral_mon_id_pre3, gral_mon_id_pre4, gral_mon_id_pre5, gral_mon_id_pre6, gral_mon_id_pre7, gral_mon_id_pre8, gral_mon_id_pre9, gral_mon_id_pre10, inv_prod_presentacion_id) FROM stdin;
5	8	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	0	0	0	0	0	0	0	0	0	1	1	1	1	1	1	1	1	1	1	1	1	1	1	1	1	1	1	1	1	0	0	0	0	0	0	0	0	0	0	1	f	2016-08-20 21:47:57.66066-04	\N	\N	0	0	0	1	1	1	1	1	1	1	1	1	1	3
6	8	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	0	0	0	0	0	0	0	0	0	0	1	1	1	1	1	1	1	1	1	1	1	1	1	1	1	1	1	1	1	1	0	0	0	0	0	0	0	0	0	0	1	f	2016-08-20 21:47:57.66066-04	\N	\N	0	0	0	1	1	1	1	1	1	1	1	1	1	4
\.


--
-- Name: inv_pre_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('inv_pre_id_seq', 6, true);


--
-- Data for Name: inv_prod; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY inv_prod (id, sku, descripcion, codigo_barras, tentrega, inv_clas_id, inv_stock_clasif_id, estatus, inv_prod_familia_id, subfamilia_id, inv_prod_grupo_id, ieps, meta_impuesto, inv_prod_linea_id, inv_mar_id, tipo_de_producto_id, inv_seccion_id, unidad_id, requiere_numero_serie, requiere_numero_lote, requiere_pedimento, permitir_stock, venta_moneda_extranjera, compra_moneda_extranjera, requiere_nom, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, id_usuario_creacion, id_usuario_actualizacion, id_usuario_baja, sucursal_id, empresa_id, cxp_prov_id, sku_aux, id_aux, densidad, valor_maximo, valor_minimo, punto_reorden, gral_impto_id, ctb_cta_id_gasto, ctb_cta_id_costo_venta, ctb_cta_id_venta, descripcion_corta, descripcion_larga, archivo_img, archivo_pdf, inv_prod_presentacion_id, flete, no_clie, gral_mon_id, gral_imptos_ret_id) FROM stdin;
1	S-21	MESCLA XK XILOL MEK		0	1	1	t	0	0	1	0		1	1	1	1	1	f	f	f	f	f	f	f	f	2015-04-22 08:40:02.080175-04	\N	\N	1	0	0	1	1	0		0	1	0	0	0	1	0	0	0					1	f		1	0
8	XXX	XXXXX		0	1	1	t	0	0	1	0		3	3	6	1	3	f	f	f	f	f	f	f	f	2016-08-20 21:47:57.66066-04	\N	\N	1	0	0	1	1	0		0	1	0	0	0	1	0	0	0					4	f		1	0
\.


--
-- Data for Name: inv_prod_cost_prom; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY inv_prod_cost_prom (id, inv_prod_id, ano, costo_promedio_1, costo_promedio_2, costo_promedio_3, costo_promedio_4, costo_promedio_5, costo_promedio_6, costo_promedio_7, costo_promedio_8, costo_promedio_9, costo_promedio_10, costo_promedio_11, costo_promedio_12, costo_ultimo_1, tipo_cambio_1, gral_mon_id_1, costo_ultimo_2, tipo_cambio_2, gral_mon_id_2, costo_ultimo_3, tipo_cambio_3, gral_mon_id_3, costo_ultimo_4, tipo_cambio_4, gral_mon_id_4, costo_ultimo_5, tipo_cambio_5, gral_mon_id_5, costo_ultimo_6, tipo_cambio_6, gral_mon_id_6, costo_ultimo_7, tipo_cambio_7, gral_mon_id_7, costo_ultimo_8, tipo_cambio_8, gral_mon_id_8, costo_ultimo_9, tipo_cambio_9, gral_mon_id_9, costo_ultimo_10, tipo_cambio_10, gral_mon_id_10, costo_ultimo_11, tipo_cambio_11, gral_mon_id_11, costo_ultimo_12, tipo_cambio_12, gral_mon_id_12, actualizacion_1, actualizacion_2, actualizacion_3, actualizacion_4, actualizacion_5, actualizacion_6, actualizacion_7, actualizacion_8, actualizacion_9, actualizacion_10, actualizacion_11, actualizacion_12, factura_ultima_1, oc_ultima_1, factura_ultima_2, oc_ultima_2, factura_ultima_3, oc_ultima_3, factura_ultima_4, oc_ultima_4, factura_ultima_5, oc_ultima_5, factura_ultima_6, oc_ultima_6, factura_ultima_7, oc_ultima_7, factura_ultima_8, oc_ultima_8, factura_ultima_9, oc_ultima_9, factura_ultima_10, oc_ultima_10, factura_ultima_11, oc_ultima_11, factura_ultima_12, oc_ultima_12) FROM stdin;
1	8	2016	0	0	0	0	0	0	0	0	0	0	0	0	0	1	1	0	1	1	0	1	1	0	1	1	0	1	1	0	1	1	0	1	1	0	1	1	0	1	1	0	1	1	0	1	1	0	1	1	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N																								
\.


--
-- Name: inv_prod_cost_prom_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('inv_prod_cost_prom_id_seq', 1, true);


--
-- Data for Name: inv_prod_familias; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY inv_prod_familias (id, identificador_familia_padre, titulo, descripcion, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_emp_id, gral_suc_id, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja, inv_prod_tipo_id) FROM stdin;
1	1	COCACOLA	COCACOLA	f	2016-08-12 00:00:00-04	\N	\N	1	1	1	0	0	0
2	2	MANZANA	MANZANA	f	2016-08-12 00:00:00-04	\N	\N	1	1	1	0	0	0
3	3	TORONJA	TORONJA	f	2016-08-16 00:00:00-04	\N	\N	1	1	1	0	0	0
4	4	SPRITE	SPRITE	f	2016-08-12 00:00:00-04	\N	\N	1	1	1	0	0	0
5	5	YOLI	YOLI	f	2016-08-12 00:00:00-04	\N	\N	1	1	1	0	0	0
\.


--
-- Name: inv_prod_familias_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('inv_prod_familias_id_seq', 1, true);


--
-- Data for Name: inv_prod_grupos; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY inv_prod_grupos (id, titulo, descripcion, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_emp_id, gral_suc_id, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja) FROM stdin;
1	GPO1	REFRESCOS	f	2016-08-13 00:00:00-04	\N	\N	1	1	1	0	0
\.


--
-- Name: inv_prod_grupos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('inv_prod_grupos_id_seq', 1, true);


--
-- Name: inv_prod_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('inv_prod_id_seq', 8, true);


--
-- Data for Name: inv_prod_lineas; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY inv_prod_lineas (id, titulo, descripcion, inv_seccion_id, borrado_logico, momento_actualizacion, momento_creacion, momento_baja, gral_emp_id, gral_suc_id, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja) FROM stdin;
1	12 OZ	12 OZ.	1	f	1980-01-09 19:00:00-05	\N	\N	1	1	1	0	0
2	16 OZ	16 OZ.	1	f	1980-01-09 19:00:00-05	\N	\N	1	1	1	0	0
3	2 L	2 LTS.	1	f	1980-01-09 19:00:00-05	\N	\N	1	1	1	0	0
4	2.5 L	2.5 LTS.	1	f	1980-01-09 19:00:00-05	\N	\N	1	1	1	0	0
5	3 L	3 LTS.	1	f	1980-01-09 19:00:00-05	\N	\N	1	1	1	0	0
\.


--
-- Name: inv_prod_lineas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('inv_prod_lineas_id_seq', 5, true);


--
-- Data for Name: inv_prod_pres_x_prod; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY inv_prod_pres_x_prod (id, producto_id, presentacion_id, producto_id_aux) FROM stdin;
9	8	3	\N
10	8	4	\N
\.


--
-- Name: inv_prod_pres_x_prod_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('inv_prod_pres_x_prod_id_seq', 10, true);


--
-- Data for Name: inv_prod_presentaciones; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY inv_prod_presentaciones (id, titulo, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_emp_id, gral_suc_id, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja, cantidad) FROM stdin;
6	MAQUILA	f	2012-09-21 09:25:21.742205-04	2015-05-20 05:02:42.82295-04	2012-09-24 05:10:19.796988-04	1	1	1	1	1	1
5	LIBRAS	f	2012-07-31 18:22:16.558238-04	2012-07-31 18:22:27.656364-04	2012-09-24 05:14:13.599269-04	1	1	1	1	1	1
4	CAJA	f	\N	2012-08-27 08:21:11.814283-04	\N	1	1	1	1	1	1
3	PIEZA	f	\N	2012-08-27 08:21:05.255844-04	\N	1	1	1	1	1	1
2	KILO	f	\N	2012-08-27 08:20:58.471273-04	\N	1	1	1	1	1	1
1	LITRO	f	\N	2012-08-27 08:20:51.299995-04	\N	1	1	1	1	1	1
\.


--
-- Name: inv_prod_presentaciones_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('inv_prod_presentaciones_id_seq', 1, false);


--
-- Data for Name: inv_prod_tipos; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY inv_prod_tipos (id, titulo, borrado_logico) FROM stdin;
4	Servicios	f
3	Kit	t
1	Prod. Terminado	f
2	Prod. Intermedio	f
5	Refacciones	f
6	Accesorios	f
7	Materia Prima	f
8	Prod. en Desarrollo	f
\.


--
-- Name: inv_prod_tipos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('inv_prod_tipos_id_seq', 1, false);


--
-- Data for Name: inv_prod_unidades; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY inv_prod_unidades (id, titulo, borrado_logico, titulo_abr, decimales) FROM stdin;
3	Pieza	f	Pza	0
5	Cajas	f	Cja	0
1	Kilogramo	f	Kg	4
2	Litro	f	L	4
4	Metro	f	M	2
8	CUBETA	t	CUBETA	0
9	SERVICIO	f	N/A	0
\.


--
-- Name: inv_prod_unidades_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('inv_prod_unidades_id_seq', 1, false);


--
-- Data for Name: inv_secciones; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY inv_secciones (id, titulo, borrado_logico, activa, momento_creacion, momento_actualizacion, momento_baja, descripcion, gral_emp_id, gral_suc_id, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja) FROM stdin;
1	SEC1	f	t	1979-12-31 19:00:00-05	\N	\N	SECCION 1	1	1	1	0	0
\.


--
-- Name: inv_secciones_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('inv_secciones_id_seq', 1, true);


--
-- Data for Name: inv_stock_clasificaciones; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY inv_stock_clasificaciones (id, titulo, descripcion, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_emp_id, gral_suc_id, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja) FROM stdin;
1	CLAS1	CLASIFICACION STOCK1	f	\N	\N	\N	1	1	1	0	0
\.


--
-- Name: inv_stock_clasificaciones_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('inv_stock_clasificaciones_id_seq', 1, true);


--
-- Data for Name: inv_suc_alm; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY inv_suc_alm (id, almacen_id, sucursal_id) FROM stdin;
1	1	1
\.


--
-- Name: inv_suc_alm_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('inv_suc_alm_id_seq', 1, false);


--
-- Data for Name: nom_deduc; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY nom_deduc (id, clave, titulo, activo, nom_deduc_tipo_id, borrado_logico, momento_creacion, momento_actualiza, momento_baja, gral_usr_id_crea, gral_usr_id_actualiza, gral_usr_id_cancela, gral_emp_id, gral_suc_id) FROM stdin;
2	002	I.S.P.T.	t	2	f	2014-04-09 12:26:05.627644-04	\N	\N	20	0	0	1	1
1	001	I.M.S.S.	t	1	f	2014-04-09 12:25:36.412666-04	2014-04-09 12:26:22.81177-04	\N	20	20	0	1	1
3	003	INFONAVIT	t	9	f	2014-04-09 12:27:57.603561-04	\N	\N	20	0	0	1	1
4	004	FALTAS	t	20	f	2014-04-09 12:28:55.189673-04	\N	\N	20	0	0	1	1
5	005	PRESTAMO EMPRESA	t	4	f	2014-04-09 12:29:30.589378-04	\N	\N	20	0	0	1	1
6	006	AGUINALDO	t	2	t	2015-01-13 07:30:56.862142-05	\N	2015-01-13 07:39:06.561286-05	37	0	0	1	1
\.


--
-- Name: nom_deduc_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('nom_deduc_id_seq', 1, false);


--
-- Data for Name: nom_deduc_tipo; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY nom_deduc_tipo (id, clave, titulo, activo) FROM stdin;
1	001	Seguridad social\n	t
2	002	ISR\n	t
3	003	Aportaciones a retiro, cesantía en edad avanzada y vejez.\n	t
4	004	Otros\n	t
5	005	Aportaciones a Fondo de vivienda\n	t
6	006	Descuento por incapacidad\n	t
7	007	Pensión alimenticia\n	t
8	008	Renta\n	t
9	009	Préstamos provenientes del Fondo Nacional de la Vivienda para los Trabajadores\n	t
10	010	Pago por crédito de vivienda\n	t
11	011	Pago de abonos INFONACOT\n	t
12	012	Anticipo de salarios\n	t
13	013	Pagos hechos con exceso al trabajador\n	t
14	014	Errores\n	t
15	015	Pérdidas\n	t
16	016	Averías\n	t
17	017	Adquisición de artículos producidos por la empresa o establecimiento\n	t
18	018	Cuotas para la constitución y fomento de sociedades cooperativas y de cajas de ahorro\n	t
19	019	Cuotas sindicales\n	t
20	020	Ausencia (Ausentismo)\n	t
21	021	Cuotas obrero patronales\n	t
\.


--
-- Name: nom_deduc_tipo_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('nom_deduc_tipo_id_seq', 1, false);


--
-- Data for Name: nom_percep; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY nom_percep (id, clave, titulo, activo, nom_percep_tipo_id, borrado_logico, momento_creacion, momento_actualiza, momento_baja, gral_usr_id_crea, gral_usr_id_actualiza, gral_usr_id_cancela, gral_emp_id, gral_suc_id) FROM stdin;
1	001	SUELDO	t	1	f	2014-04-09 11:56:51.592842-04	2014-04-09 11:57:20.915139-04	\N	20	20	0	1	1
3	003	AGUINALDO	t	2	f	2014-04-09 12:15:08.030891-04	\N	\N	20	0	0	1	1
4	004	PREMIO PUNTUALIDAD	t	10	f	2014-04-09 12:15:51.543651-04	\N	\N	20	0	0	1	1
5	005	TIEMPO EXTRA	t	19	f	2014-04-09 12:19:26.192793-04	\N	\N	20	0	0	1	1
6	006	PRIMA VACACIONES	t	21	f	2014-04-09 12:19:57.782522-04	\N	\N	20	0	0	1	1
2	002	VALES DE DESPENSA	f	7	t	2014-04-09 12:14:44.730578-04	2014-04-09 12:21:07.298992-04	2014-04-09 12:21:28.696457-04	20	20	0	1	1
7	007	VALES DE DESPENSA	t	29	f	2014-04-09 12:22:10.694126-04	\N	\N	20	0	0	1	1
8	008	SUBSIDIO AL EMPLEO	t	17	f	2014-04-10 06:46:57.25754-04	\N	\N	20	0	0	1	1
9	009	PERSEPCION 	t	2	f	2015-01-13 07:40:14.19252-05	\N	\N	37	0	0	1	1
10	010	FINIQUITO	t	25	f	2016-02-02 11:03:27.818135-05	\N	\N	22	0	0	1	1
\.


--
-- Name: nom_percep_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('nom_percep_id_seq', 1, false);


--
-- Data for Name: nom_percep_tipo; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY nom_percep_tipo (id, clave, titulo, activo) FROM stdin;
1	001	Sueldos, Salarios  Rayas y Jornales\n	t
2	002	Gratificación Anual (Aguinaldo)\n	t
3	003	Participación de los Trabajadores en las Utilidades PTU\n	t
4	004	Reembolso de Gastos Médicos Dentales y Hospitalarios\n	t
5	005	Fondo de Ahorro\n	t
6	006	Caja de ahorro\n	t
7	007	Vales\n	t
8	008	Ayudas\n	t
9	009	Contribuciones a Cargo del Trabajador Pagadas por el Patrón\n	t
10	010	Premios por puntualidad\n	t
11	011	Prima de Seguro de vida\n	t
12	012	Seguro de Gastos Medicos Mayores\n	t
13	013	Cuotas Sindicales Pagadas por el Patrón\n	t
14	014	Subsidios por incapacidad\n	t
15	015	Becas para trabajadores y/o hijos\n	t
16	016	Otros\n	t
17	017	Subsidio para el empleo\n	t
18	018	Fomento al primer empleo\n	t
19	019	Horas extra\n	t
20	020	Prima dominical\n	t
21	021	Prima vacacional\n	t
22	022	Prima por antigüedad\n	t
23	023	Pagos por separación\n	t
24	024	Seguro de retiro\n	t
25	025	Indemnizaciones\n	t
26	026	Reembolso por funeral\n	t
27	027	Cuotas de seguridad social pagadas por el patrón\n	t
28	028	Comisiones\n	t
29	029	Vales de despensa\n	t
30	030	Vales de restaurante\n	t
31	031	Vales de gasolina\n	t
32	032	Vales de ropa\n	t
33	033	Ayuda para renta\n	t
34	034	Ayuda para artículos escolares\n	t
35	035	Ayuda para anteojos\n	t
36	036	Ayuda para transporte\n	t
37	037	Ayuda para gastos de funeral\n	t
38	038	Otros ingresos por salarios\n	t
39	039	Jubilaciones, pensiones o haberes de retiro\n	t
\.


--
-- Name: nom_percep_tipo_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('nom_percep_tipo_id_seq', 1, false);


--
-- Data for Name: nom_periodicidad_pago; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY nom_periodicidad_pago (id, titulo, no_periodos, activo, borrado_logico, momento_creacion, momento_actualiza, momento_baja, gral_usr_id_crea, gral_usr_id_actualiza, gral_usr_id_baja, gral_emp_id, gral_suc_id) FROM stdin;
1	SEMANAL	53	t	f	2016-08-19 00:00:00-04	\N	\N	1	0	0	1	1
\.


--
-- Name: nom_periodicidad_pago_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('nom_periodicidad_pago_id_seq', 1, false);


--
-- Data for Name: nom_periodos_conf; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY nom_periodos_conf (id, ano, nom_periodicidad_pago_id, prefijo, borrado_logico, momento_creacion, momento_actualiza, momento_baja, gral_usr_id_crea, gral_usr_id_actualiza, gral_usr_id_baja, gral_emp_id, gral_suc_id) FROM stdin;
1	2016	1	S	f	2016-01-17 19:00:00-05	\N	\N	1	0	0	1	1
\.


--
-- Data for Name: nom_periodos_conf_det; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY nom_periodos_conf_det (id, nom_periodos_conf_id, folio, titulo, fecha_ini, fecha_fin, estatus) FROM stdin;
3	1	16	PAGO DE NOMINA DEL 15/04/2016 AL 21/04/2016	2016-04-15	2016-04-21	f
4	1	17	PAGO DE NOMINA DEL 22/04/2016 AL 28/04/2016	2016-04-22	2016-04-28	f
5	1	18	PAGO DE NOMINA DEL 29/04/2016 AL 05/05/2016	2016-04-29	2016-05-05	f
6	1	19	PAGO DE NOMINA DEL 06/05/2016 AL 12/05/2016	2016-05-06	2016-05-12	f
7	1	20	PAGO DE NOMINA DEL 13/05/2016 AL 19/05/2016	2016-05-13	2016-05-19	f
8	1	21	PAGO DE NOMINA DEL 20/05/2016 AL 26/05/2016	2016-05-20	2016-05-26	f
9	1	22	PAGO DE NOMINA DEL 27/05/2016 AL 02/06/2016	2016-05-27	2016-06-02	f
10	1	23	PAGO DE NOMINA DEL 03/06/2016 AL 09/06/2016	2016-06-03	2016-06-09	f
11	1	24	PAGO DE NOMINA DEL 10/06/2016 AL 16/06/2016	2016-06-10	2016-06-16	f
12	1	25	PAGO DE NOMINA DEL 17/06/2016 AL 23/06/2016	2016-06-17	2016-06-23	f
13	1	26	PAGO DE NOMINA DEL 24/06/2016 AL 30/06/2016	2016-06-24	2016-06-30	f
14	1	27	PAGO DE NOMINA DEL 01/07/2016 AL 07/07/2016	2016-07-01	2016-07-07	f
15	1	28	PAGO DE NOMINA DEL 08/07/2016 AL 14/07/2016	2016-07-08	2016-07-14	f
16	1	29	PAGO DE NOMINA DEL 15/07/2016 AL 21/07/2016	2016-07-15	2016-07-21	f
17	1	30	PAGO DE NOMINA DEL 22/07/2016 AL 28/07/2016	2016-07-22	2016-07-28	f
18	1	31	PAGO DE NOMINA DEL 29/07/2016 AL 04/08/2016	2016-07-29	2016-08-04	f
19	1	32	PAGO DE NOMINA DEL 05/08/2016 AL 11/08/2016	2016-08-05	2016-08-11	f
20	1	33	PAGO DE NOMINA DEL 12/08/2016 AL 18/08/2016	2016-08-12	2016-08-18	f
21	1	34	PAGO DE NOMINA DEL 19/08/2016 AL 25/08/2016	2016-08-19	2016-08-25	f
22	1	35	PAGO DE NOMINA DEL 26/08/2016 AL 01/09/2016	2016-08-26	2016-09-01	f
23	1	36	PAGO DE NOMINA DEL 02/09/2016 AL 08/09/2016	2016-09-02	2016-09-08	f
24	1	37	PAGO DE NOMINA DEL 09/09/2016 AL 15/09/2016	2016-09-09	2016-09-15	f
25	1	38	PAGO DE NOMINA DEL 16/09/2016 AL 22/09/2016	2016-09-16	2016-09-22	f
26	1	39	PAGO DE NOMINA DEL 23/09/2016 AL 29/09/2016	2016-09-23	2016-09-29	f
27	1	40	PAGO DE NOMINA DEL 30/09/2016 AL 06/10/2016	2016-09-30	2016-10-06	f
28	1	41	PAGO DE NOMINA DEL 07/10/2016 AL 13/10/2016	2016-10-07	2016-10-13	f
29	1	42	PAGO DE NOMINA DEL 14/10/2016 AL 20/10/2016	2016-10-14	2016-10-20	f
30	1	43	PAGO DE NOMINA DEL 21/10/2016 AL 27/10/2016	2016-10-21	2016-10-27	f
31	1	44	PAGO DE NOMINA DEL 28/10/2016 AL 03/11/2016	2016-10-28	2016-11-03	f
32	1	45	PAGO DE NOMINA DEL 04/11/2016 AL 10/11/2016	2016-11-04	2016-11-10	f
33	1	46	PAGO DE NOMINA DEL 11/11/2016 AL 17/11/2016	2016-11-11	2016-11-17	f
34	1	47	PAGO DE NOMINA DEL 18/11/2016 AL 24/11/2016	2016-11-18	2016-11-24	f
35	1	48	PAGO DE NOMINA DEL 25/11/2016 AL 01/12/2016	2016-11-25	2016-12-01	f
36	1	49	PAGO DE NOMINA DEL 02/12/2016 AL 08/12/2016	2016-12-02	2016-12-08	f
37	1	50	PAGO DE NOMINA DEL 09/12/2016 AL 15/12/2016	2016-12-09	2016-12-15	f
38	1	51	PAGO DE NOMINA DEL 16/12/2016 AL 22/12/2016	2016-12-16	2016-12-22	f
39	1	52	PAGO DE NOMINA DEL 23/12/2016 AL 29/12/2016	2016-12-23	2016-12-29	f
1	1	14	PAGO DE NOMINA DEL 01/04/2016 AL 07/04/2016	2016-04-01	2016-04-07	f
2	1	15	PAGO DE NOMINA DEL 08/04/2016 AL 14/04/2016	2016-04-08	2016-04-14	f
\.


--
-- Name: nom_periodos_conf_det_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('nom_periodos_conf_det_id_seq', 2, true);


--
-- Name: nom_periodos_conf_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('nom_periodos_conf_id_seq', 1, true);


--
-- Data for Name: nom_regimen_contratacion; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY nom_regimen_contratacion (id, clave, titulo, activo) FROM stdin;
10	10	Asimilados a salarios, Ingresos acciones o títulos valor\n	t
9	9	Asimilados a salarios, Honorarios asimilados a salarios\n	t
8	8	Asimilados a salarios, Actividad empresarial (comisionistas)\n	t
7	7	Asimilados a salarios, Miembros de consejos directivos, de vigilancia, consultivos, honorarios a administradores, comisarios y gerentes generales.\n	t
6	6	Asimilados a salarios, Integrantes de Sociedades y Asociaciones Civiles\n	t
5	5	Asimilados a salarios, Miembros de las Sociedades Cooperativas de Producción.\n	t
4	4	Pensionados\n	t
3	3	Jubilados\n	t
2	2	Sueldos y salarios\n	t
\.


--
-- Name: nom_regimen_contratacion_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('nom_regimen_contratacion_id_seq', 1, false);


--
-- Data for Name: nom_riesgo_puesto; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY nom_riesgo_puesto (id, clave, titulo, activo) FROM stdin;
1	1	Clase I	t
2	2	Clase II	t
3	3	Clase III	t
4	4	Clase IV	t
5	5	Clase V	t
\.


--
-- Name: nom_riesgo_puesto_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('nom_riesgo_puesto_id_seq', 1, false);


--
-- Data for Name: nom_tipo_contrato; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY nom_tipo_contrato (id, titulo, activo) FROM stdin;
1	Base	t
2	Eventual	t
3	Sindicalizado	t
4	A prueba	t
\.


--
-- Name: nom_tipo_contrato_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('nom_tipo_contrato_id_seq', 1, false);


--
-- Data for Name: nom_tipo_hrs_extra; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY nom_tipo_hrs_extra (id, titulo, activo) FROM stdin;
1	Dobles	t
2	Triples	t
\.


--
-- Name: nom_tipo_hrs_extra_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('nom_tipo_hrs_extra_id_seq', 1, false);


--
-- Data for Name: nom_tipo_incapacidad; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY nom_tipo_incapacidad (id, clave, titulo, activo) FROM stdin;
1	1	Riesgo de trabajo	t
2	2	Enfermedad en general	t
3	3	Maternidad	t
\.


--
-- Name: nom_tipo_incapacidad_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('nom_tipo_incapacidad_id_seq', 1, false);


--
-- Data for Name: nom_tipo_jornada; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY nom_tipo_jornada (id, titulo, activo) FROM stdin;
1	Diurna	t
2	Nocturna	t
3	Mixta	t
4	Por hora	t
\.


--
-- Name: nom_tipo_jornada_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('nom_tipo_jornada_id_seq', 1, false);


--
-- Data for Name: poc_pedidos; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY poc_pedidos (id, folio, cxc_clie_id, moneda_id, observaciones, subtotal, impuesto, monto_retencion, total, tasa_retencion_immex, tipo_cambio, cxc_agen_id, cxp_prov_credias_id, orden_compra, proceso_id, fecha_compromiso, lugar_entrega, transporte, cancelado, borrado_logico, momento_creacion, momento_actualizacion, momento_cancelacion, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_cancelacion, tipo_documento, gral_usr_id_autoriza, momento_autorizacion, fac_metodos_pago_id, no_cuenta, enviar_ruta, inv_alm_id, cxc_clie_df_id, enviar_obser_fac, flete, monto_ieps, monto_descto, motivo_descto, porcentaje_descto, folio_cot) FROM stdin;
\.


--
-- Data for Name: poc_pedidos_detalle; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY poc_pedidos_detalle (id, poc_pedido_id, inv_prod_id, presentacion_id, cantidad, precio_unitario, gral_imp_id, valor_imp, facturado, reservado, backorder, inv_prod_unidad_id, gral_ieps_id, valor_ieps, descto, requisicion, requiere_aut, autorizado, precio_aut, gral_usr_id_aut, gral_imptos_ret_id, tasa_ret) FROM stdin;
\.


--
-- Name: poc_pedidos_detalle_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('poc_pedidos_detalle_id_seq', 1, false);


--
-- Name: poc_pedidos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('poc_pedidos_id_seq', 1, false);


--
-- Data for Name: tes_ban; Type: TABLE DATA; Schema: public; Owner: sumar
--

COPY tes_ban (id, titulo, descripcion, borrado_logico, momento_creacion, momento_actualizacion, momento_baja, gral_emp_id, gral_suc_id, gral_usr_id_creacion, gral_usr_id_actualizacion, gral_usr_id_baja, clave) FROM stdin;
2	HSBC	H S B C	f	2012-07-18 11:16:38.509398-04	2012-07-20 10:24:23.691652-04	\N	1	1	1	1	0	
3	BBVA BANCOMER	BILBAO BIZCAYA BANCOMER	f	2012-07-18 11:16:53.186461-04	2014-01-22 09:44:46.433847-05	\N	1	1	1	1	0	
1	BANORTE	BANCO MERCANTIL DEL NORTE	f	2012-07-18 11:16:07.431452-04	\N	\N	1	1	1	1	0	
4	BANAMEX	BANAMEX	f	2012-07-18 11:17:14.12411-04	\N	\N	1	1	1	1	0	
5	BANCRECER	BANCRECER	f	2012-07-18 11:17:24.717463-04	\N	\N	1	1	1	1	0	
6	BANREGIO	BANREGIO	f	2012-07-18 11:17:34.990161-04	\N	\N	1	1	1	1	0	
7	SANTANDER	SANTANDER SERFIN	f	2012-07-20 10:19:45.721521-04	\N	\N	1	1	1	1	0	
8	AFIRME	BANCA AFIRME	f	2012-07-20 10:19:59.637186-04	\N	\N	1	1	1	1	0	
9	BAJIO	BANCO DEL BAJIO	f	2012-07-20 10:20:17.660245-04	\N	\N	1	1	1	1	0	
10	SCOTIA	SCOTIA BANK	f	2012-07-20 10:20:37.063995-04	\N	\N	1	1	1	1	0	
11	INBURSA	INBURSA	f	2012-07-20 10:21:37.021768-04	\N	\N	1	1	1	1	0	
12	BNCRD	BANCREDITO	f	2012-07-20 10:22:07.711303-04	\N	\N	1	1	1	1	0	
13	NO IDENTIFICADO	BANCO NO IDENTIFICADO	f	2012-07-25 12:54:26.653028-04	\N	\N	1	1	1	1	0	
14	COMPASS BANK	COMPASS BANK USA	f	2012-10-09 09:33:55.879867-04	\N	\N	1	1	1	1	0	
\.


--
-- Name: tes_ban_id_seq; Type: SEQUENCE SET; Schema: public; Owner: sumar
--

SELECT pg_catalog.setval('tes_ban_id_seq', 1, false);


--
-- Name: clients_consignacions_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_clients_consignacions
    ADD CONSTRAINT clients_consignacions_pkey PRIMARY KEY (id);


--
-- Name: ctb_may_clases_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY ctb_may_clases
    ADD CONSTRAINT ctb_may_clases_pkey PRIMARY KEY (id);


--
-- Name: ctb_may_clases_titulo_key; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY ctb_may_clases
    ADD CONSTRAINT ctb_may_clases_titulo_key UNIQUE (titulo);


--
-- Name: cxc_clie_clas1_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_clas1
    ADD CONSTRAINT cxc_clie_clas1_pkey PRIMARY KEY (id);


--
-- Name: cxc_clie_clas2_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_clas2
    ADD CONSTRAINT cxc_clie_clas2_pkey PRIMARY KEY (id);


--
-- Name: cxc_clie_clas3_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_clas3
    ADD CONSTRAINT cxc_clie_clas3_pkey PRIMARY KEY (id);


--
-- Name: cxc_clie_clases_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_clases
    ADD CONSTRAINT cxc_clie_clases_pkey PRIMARY KEY (id);


--
-- Name: cxc_clie_creapar_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_creapar
    ADD CONSTRAINT cxc_clie_creapar_pkey PRIMARY KEY (id);


--
-- Name: cxc_clie_credias_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_credias
    ADD CONSTRAINT cxc_clie_credias_pkey PRIMARY KEY (id);


--
-- Name: cxc_clie_df_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_df
    ADD CONSTRAINT cxc_clie_df_pkey PRIMARY KEY (id);


--
-- Name: cxc_clie_grupos_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_grupos
    ADD CONSTRAINT cxc_clie_grupos_pkey PRIMARY KEY (id);


--
-- Name: cxc_clie_grupos_titulo_key; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_grupos
    ADD CONSTRAINT cxc_clie_grupos_titulo_key UNIQUE (titulo);


--
-- Name: cxc_clie_numero_control_key; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie
    ADD CONSTRAINT cxc_clie_numero_control_key UNIQUE (numero_control);


--
-- Name: cxc_clie_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie
    ADD CONSTRAINT cxc_clie_pkey PRIMARY KEY (id);


--
-- Name: cxc_clie_tipos_embarque_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_tipos_embarque
    ADD CONSTRAINT cxc_clie_tipos_embarque_pkey PRIMARY KEY (id);


--
-- Name: cxc_clie_zonas_key; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_zonas
    ADD CONSTRAINT cxc_clie_zonas_key UNIQUE (titulo);


--
-- Name: cxc_clie_zonas_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_zonas
    ADD CONSTRAINT cxc_clie_zonas_pkey PRIMARY KEY (id);


--
-- Name: cxp_prov_clas1_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_clas1
    ADD CONSTRAINT cxp_prov_clas1_pkey PRIMARY KEY (id);


--
-- Name: cxp_prov_clas2_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_clas2
    ADD CONSTRAINT cxp_prov_clas2_pkey PRIMARY KEY (id);


--
-- Name: cxp_prov_clas3_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_clas3
    ADD CONSTRAINT cxp_prov_clas3_pkey PRIMARY KEY (id);


--
-- Name: cxp_prov_creapar_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_creapar
    ADD CONSTRAINT cxp_prov_creapar_pkey PRIMARY KEY (id);


--
-- Name: cxp_prov_credias_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_credias
    ADD CONSTRAINT cxp_prov_credias_pkey PRIMARY KEY (id);


--
-- Name: cxp_prov_folio_borrado_logico_key; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov
    ADD CONSTRAINT cxp_prov_folio_borrado_logico_key UNIQUE (folio, borrado_logico);


--
-- Name: cxp_prov_grupos_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_grupos
    ADD CONSTRAINT cxp_prov_grupos_pkey PRIMARY KEY (id);


--
-- Name: cxp_prov_grupos_titulo_key; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_grupos
    ADD CONSTRAINT cxp_prov_grupos_titulo_key UNIQUE (titulo);


--
-- Name: cxp_prov_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov
    ADD CONSTRAINT cxp_prov_pkey PRIMARY KEY (id);


--
-- Name: cxp_prov_rfc_borrado_logico_key; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov
    ADD CONSTRAINT cxp_prov_rfc_borrado_logico_key UNIQUE (rfc, borrado_logico);


--
-- Name: cxp_prov_rfc_razon_social_borrado_logido_key; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov
    ADD CONSTRAINT cxp_prov_rfc_razon_social_borrado_logido_key UNIQUE (rfc, razon_social, borrado_logico);


--
-- Name: cxp_prov_tipos_embarque_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_tipos_embarque
    ADD CONSTRAINT cxp_prov_tipos_embarque_pkey PRIMARY KEY (id);


--
-- Name: cxp_zonas_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_zonas
    ADD CONSTRAINT cxp_zonas_pkey PRIMARY KEY (id);


--
-- Name: denominacion_vers_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_monedavers
    ADD CONSTRAINT denominacion_vers_pkey PRIMARY KEY (id);


--
-- Name: erp_pagos_formas_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_pagos_formas
    ADD CONSTRAINT erp_pagos_formas_pkey PRIMARY KEY (id);


--
-- Name: erp_prefacturas_detalles_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_prefacturas_detalles
    ADD CONSTRAINT erp_prefacturas_detalles_pkey PRIMARY KEY (id);


--
-- Name: erp_prefacturas_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_prefacturas
    ADD CONSTRAINT erp_prefacturas_pkey PRIMARY KEY (id);


--
-- Name: erp_proceso_flujo_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_proceso_flujo
    ADD CONSTRAINT erp_proceso_flujo_pkey PRIMARY KEY (id);


--
-- Name: erp_proceso_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_proceso
    ADD CONSTRAINT erp_proceso_pkey PRIMARY KEY (id);


--
-- Name: erp_tiempos_entrega_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_tiempos_entrega
    ADD CONSTRAINT erp_tiempos_entrega_pkey PRIMARY KEY (id);


--
-- Name: erp_users_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_usr
    ADD CONSTRAINT erp_users_pkey PRIMARY KEY (id);


--
-- Name: fac_cfds_conf_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_cfds_conf
    ADD CONSTRAINT fac_cfds_conf_pkey PRIMARY KEY (id);


--
-- Name: fac_metodos_pago_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_metodos_pago
    ADD CONSTRAINT fac_metodos_pago_pkey PRIMARY KEY (id);


--
-- Name: fac_namespaces_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_namespaces
    ADD CONSTRAINT fac_namespaces_pkey PRIMARY KEY (id);


--
-- Name: fac_nomina_det_deduc_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_nomina_det_deduc
    ADD CONSTRAINT fac_nomina_det_deduc_pkey PRIMARY KEY (id);


--
-- Name: fac_nomina_det_hrs_extra_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_nomina_det_hrs_extra
    ADD CONSTRAINT fac_nomina_det_hrs_extra_pkey PRIMARY KEY (id);


--
-- Name: fac_nomina_det_incapa_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_nomina_det_incapa
    ADD CONSTRAINT fac_nomina_det_incapa_pkey PRIMARY KEY (id);


--
-- Name: fac_nomina_det_percep_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_nomina_det_percep
    ADD CONSTRAINT fac_nomina_det_percep_pkey PRIMARY KEY (id);


--
-- Name: fac_nomina_det_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_nomina_det
    ADD CONSTRAINT fac_nomina_det_pkey PRIMARY KEY (id);


--
-- Name: fac_nomina_par_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_nomina_par
    ADD CONSTRAINT fac_nomina_par_pkey PRIMARY KEY (id);


--
-- Name: fac_nomina_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_nomina
    ADD CONSTRAINT fac_nomina_pkey PRIMARY KEY (id);


--
-- Name: fac_par_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_par
    ADD CONSTRAINT fac_par_pkey PRIMARY KEY (id);


--
-- Name: fleteras_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_fleteras
    ADD CONSTRAINT fleteras_pkey PRIMARY KEY (id);


--
-- Name: gral_app_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_app
    ADD CONSTRAINT gral_app_pkey PRIMARY KEY (id);


--
-- Name: gral_app_titulo_key; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_app
    ADD CONSTRAINT gral_app_titulo_key UNIQUE (descripcion);


--
-- Name: gral_categ_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_categ
    ADD CONSTRAINT gral_categ_pkey PRIMARY KEY (id);


--
-- Name: gral_civils_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_civils
    ADD CONSTRAINT gral_civils_pkey PRIMARY KEY (id);


--
-- Name: gral_cons_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_cons
    ADD CONSTRAINT gral_cons_pkey PRIMARY KEY (id);


--
-- Name: gral_cons_tipos_key; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_cons_tipos
    ADD CONSTRAINT gral_cons_tipos_key UNIQUE (titulo);


--
-- Name: gral_cons_tipos_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_cons_tipos
    ADD CONSTRAINT gral_cons_tipos_pkey PRIMARY KEY (id);


--
-- Name: gral_deptos_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_deptos
    ADD CONSTRAINT gral_deptos_pkey PRIMARY KEY (id);


--
-- Name: gral_deptos_turnos_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_deptos_turnos
    ADD CONSTRAINT gral_deptos_turnos_pkey PRIMARY KEY (id);


--
-- Name: gral_dias_no_laborables_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_dias_no_laborables
    ADD CONSTRAINT gral_dias_no_laborables_pkey PRIMARY KEY (id);


--
-- Name: gral_edo_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_edo
    ADD CONSTRAINT gral_edo_pkey PRIMARY KEY (id);


--
-- Name: gral_emails_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_emails
    ADD CONSTRAINT gral_emails_pkey PRIMARY KEY (id);


--
-- Name: gral_emp_leyenda_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_emp_leyenda
    ADD CONSTRAINT gral_emp_leyenda_pkey PRIMARY KEY (id);


--
-- Name: gral_empleado_deduc_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_empleado_deduc
    ADD CONSTRAINT gral_empleado_deduc_pkey PRIMARY KEY (id);


--
-- Name: gral_empleado_percep_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_empleado_percep
    ADD CONSTRAINT gral_empleado_percep_pkey PRIMARY KEY (id);


--
-- Name: gral_empleados_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_empleados
    ADD CONSTRAINT gral_empleados_pkey PRIMARY KEY (id);


--
-- Name: gral_escolaridads_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_escolaridads
    ADD CONSTRAINT gral_escolaridads_pkey PRIMARY KEY (id);


--
-- Name: gral_ieps_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_ieps
    ADD CONSTRAINT gral_ieps_pkey PRIMARY KEY (id);


--
-- Name: gral_imptos_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_imptos
    ADD CONSTRAINT gral_imptos_pkey PRIMARY KEY (id);


--
-- Name: gral_imptos_ret_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_imptos_ret
    ADD CONSTRAINT gral_imptos_ret_pkey PRIMARY KEY (id);


--
-- Name: gral_isr_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_isr
    ADD CONSTRAINT gral_isr_pkey PRIMARY KEY (id);


--
-- Name: gral_mon_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_mon
    ADD CONSTRAINT gral_mon_pkey PRIMARY KEY (id);


--
-- Name: gral_mun_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_mun
    ADD CONSTRAINT gral_mun_pkey PRIMARY KEY (id);


--
-- Name: gral_pais_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_pais
    ADD CONSTRAINT gral_pais_pkey PRIMARY KEY (id);


--
-- Name: gral_pais_titulo_key; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_pais
    ADD CONSTRAINT gral_pais_titulo_key UNIQUE (titulo);


--
-- Name: gral_plazas_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_plazas
    ADD CONSTRAINT gral_plazas_pkey PRIMARY KEY (id);


--
-- Name: gral_puestos_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_puestos
    ADD CONSTRAINT gral_puestos_pkey PRIMARY KEY (id);


--
-- Name: gral_reg_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_reg
    ADD CONSTRAINT gral_reg_pkey PRIMARY KEY (id);


--
-- Name: gral_religions_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_religions
    ADD CONSTRAINT gral_religions_pkey PRIMARY KEY (id);


--
-- Name: gral_rols_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_rol
    ADD CONSTRAINT gral_rols_pkey PRIMARY KEY (id);


--
-- Name: gral_sangretipos_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_sangretipos
    ADD CONSTRAINT gral_sangretipos_pkey PRIMARY KEY (id);


--
-- Name: gral_sexos_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_sexos
    ADD CONSTRAINT gral_sexos_pkey PRIMARY KEY (id);


--
-- Name: gral_sis_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_emp
    ADD CONSTRAINT gral_sis_pkey PRIMARY KEY (id);


--
-- Name: gral_sis_titulo_key; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_emp
    ADD CONSTRAINT gral_sis_titulo_key UNIQUE (titulo);


--
-- Name: gral_suc_pza_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_suc_pza
    ADD CONSTRAINT gral_suc_pza_pkey PRIMARY KEY (id);


--
-- Name: gral_suc_titulo_key; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_suc
    ADD CONSTRAINT gral_suc_titulo_key UNIQUE (titulo);


--
-- Name: gral_sucursales_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_suc
    ADD CONSTRAINT gral_sucursales_pkey PRIMARY KEY (id);


--
-- Name: gral_tc_url_key; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_tc_url
    ADD CONSTRAINT gral_tc_url_key UNIQUE (url);


--
-- Name: gral_tc_url_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_tc_url
    ADD CONSTRAINT gral_tc_url_pkey PRIMARY KEY (id);


--
-- Name: gral_usr_rol_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_usr_rol
    ADD CONSTRAINT gral_usr_rol_pkey PRIMARY KEY (id);


--
-- Name: gral_usr_suc_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_usr_suc
    ADD CONSTRAINT gral_usr_suc_pkey PRIMARY KEY (id);


--
-- Name: h_facturas_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_h_facturas
    ADD CONSTRAINT h_facturas_pkey PRIMARY KEY (id);


--
-- Name: inv_alm_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_alm
    ADD CONSTRAINT inv_alm_pkey PRIMARY KEY (id);


--
-- Name: inv_alm_tipos_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_alm_tipos
    ADD CONSTRAINT inv_alm_tipos_pkey PRIMARY KEY (id);


--
-- Name: inv_alm_titulo_key; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_alm
    ADD CONSTRAINT inv_alm_titulo_key UNIQUE (titulo);


--
-- Name: inv_clas_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_clas
    ADD CONSTRAINT inv_clas_pkey PRIMARY KEY (id);


--
-- Name: inv_cxc_clie_descto_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_descto
    ADD CONSTRAINT inv_cxc_clie_descto_pkey PRIMARY KEY (id);


--
-- Name: inv_exi_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_exi
    ADD CONSTRAINT inv_exi_pkey PRIMARY KEY (id);


--
-- Name: inv_kit_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_kit
    ADD CONSTRAINT inv_kit_pkey PRIMARY KEY (id);


--
-- Name: inv_mar_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_mar
    ADD CONSTRAINT inv_mar_pkey PRIMARY KEY (id);


--
-- Name: inv_mov_tipos_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_mov_tipos
    ADD CONSTRAINT inv_mov_tipos_pkey PRIMARY KEY (id);


--
-- Name: inv_pre_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_pre
    ADD CONSTRAINT inv_pre_pkey PRIMARY KEY (id);


--
-- Name: inv_prod_cost_prom_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_prod_cost_prom
    ADD CONSTRAINT inv_prod_cost_prom_pkey PRIMARY KEY (id);


--
-- Name: inv_prod_familias_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_prod_familias
    ADD CONSTRAINT inv_prod_familias_pkey PRIMARY KEY (id);


--
-- Name: inv_prod_grupos_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_prod_grupos
    ADD CONSTRAINT inv_prod_grupos_pkey PRIMARY KEY (id);


--
-- Name: inv_prod_lineas_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_prod_lineas
    ADD CONSTRAINT inv_prod_lineas_pkey PRIMARY KEY (id);


--
-- Name: inv_prod_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_prod
    ADD CONSTRAINT inv_prod_pkey PRIMARY KEY (id);


--
-- Name: inv_prod_pres_x_prod_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_prod_pres_x_prod
    ADD CONSTRAINT inv_prod_pres_x_prod_pkey PRIMARY KEY (id);


--
-- Name: inv_prod_tipos_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_prod_tipos
    ADD CONSTRAINT inv_prod_tipos_pkey PRIMARY KEY (id);


--
-- Name: inv_prod_unidades_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_prod_unidades
    ADD CONSTRAINT inv_prod_unidades_pkey PRIMARY KEY (id);


--
-- Name: inv_prod_unidades_titulo_key; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_prod_unidades
    ADD CONSTRAINT inv_prod_unidades_titulo_key UNIQUE (titulo);


--
-- Name: inv_secciones_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_secciones
    ADD CONSTRAINT inv_secciones_pkey PRIMARY KEY (id);


--
-- Name: inv_stock_clasificaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_stock_clasificaciones
    ADD CONSTRAINT inv_stock_clasificaciones_pkey PRIMARY KEY (id);


--
-- Name: inv_suc_alm_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_suc_alm
    ADD CONSTRAINT inv_suc_alm_pkey PRIMARY KEY (id);


--
-- Name: mascaras_para_validaciones_por_app_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_mascaras_para_validaciones_por_app
    ADD CONSTRAINT mascaras_para_validaciones_por_app_pkey PRIMARY KEY (id);


--
-- Name: nom_conf_periodo_pago_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_periodos_conf
    ADD CONSTRAINT nom_conf_periodo_pago_pkey PRIMARY KEY (id);


--
-- Name: nom_deduc_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_deduc
    ADD CONSTRAINT nom_deduc_pkey PRIMARY KEY (id);


--
-- Name: nom_deduc_tipo_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_deduc_tipo
    ADD CONSTRAINT nom_deduc_tipo_pkey PRIMARY KEY (id);


--
-- Name: nom_percep_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_percep
    ADD CONSTRAINT nom_percep_pkey PRIMARY KEY (id);


--
-- Name: nom_percep_tipo_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_percep_tipo
    ADD CONSTRAINT nom_percep_tipo_pkey PRIMARY KEY (id);


--
-- Name: nom_periodicidad_pago_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_periodicidad_pago
    ADD CONSTRAINT nom_periodicidad_pago_pkey PRIMARY KEY (id);


--
-- Name: nom_periodos_conf_det_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_periodos_conf_det
    ADD CONSTRAINT nom_periodos_conf_det_pkey PRIMARY KEY (id);


--
-- Name: nom_regimen_contratacion_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_regimen_contratacion
    ADD CONSTRAINT nom_regimen_contratacion_pkey PRIMARY KEY (id);


--
-- Name: nom_riesgo_puesto_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_riesgo_puesto
    ADD CONSTRAINT nom_riesgo_puesto_pkey PRIMARY KEY (id);


--
-- Name: nom_tipo_contrato_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_tipo_contrato
    ADD CONSTRAINT nom_tipo_contrato_pkey PRIMARY KEY (id);


--
-- Name: nom_tipo_hrs_extra_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_tipo_hrs_extra
    ADD CONSTRAINT nom_tipo_hrs_extra_pkey PRIMARY KEY (id);


--
-- Name: nom_tipo_incapacidad_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_tipo_incapacidad
    ADD CONSTRAINT nom_tipo_incapacidad_pkey PRIMARY KEY (id);


--
-- Name: nom_tipo_jornada_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_tipo_jornada
    ADD CONSTRAINT nom_tipo_jornada_pkey PRIMARY KEY (id);


--
-- Name: parametros_generales_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_parametros_generales
    ADD CONSTRAINT parametros_generales_pkey PRIMARY KEY (id);


--
-- Name: parametros_generales_variable_key; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY erp_parametros_generales
    ADD CONSTRAINT parametros_generales_variable_key UNIQUE (variable);


--
-- Name: poc_pedidos_detalle_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY poc_pedidos_detalle
    ADD CONSTRAINT poc_pedidos_detalle_pkey PRIMARY KEY (id);


--
-- Name: poc_pedidos_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY poc_pedidos
    ADD CONSTRAINT poc_pedidos_pkey PRIMARY KEY (id);


--
-- Name: presentaciones_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_prod_presentaciones
    ADD CONSTRAINT presentaciones_pkey PRIMARY KEY (id);


--
-- Name: proveedor_contactos_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_contactos
    ADD CONSTRAINT proveedor_contactos_pkey PRIMARY KEY (id);


--
-- Name: proveedor_tipos_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_clases
    ADD CONSTRAINT proveedor_tipos_pkey PRIMARY KEY (id);


--
-- Name: proveedor_tipos_titulo_key; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov_clases
    ADD CONSTRAINT proveedor_tipos_titulo_key UNIQUE (titulo);


--
-- Name: tes_ban_pkey; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY tes_ban
    ADD CONSTRAINT tes_ban_pkey PRIMARY KEY (id);


--
-- Name: unique_emp_clave_suc; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_suc
    ADD CONSTRAINT unique_emp_clave_suc UNIQUE (empresa_id, clave, borrado_logico);


--
-- Name: unique_gral_emp_no_id; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_emp
    ADD CONSTRAINT unique_gral_emp_no_id UNIQUE (no_id);


--
-- Name: unique_gral_empleado_deduc; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_empleado_deduc
    ADD CONSTRAINT unique_gral_empleado_deduc UNIQUE (gral_empleado_id, nom_deduc_id);


--
-- Name: unique_gral_empleado_percep; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_empleado_percep
    ADD CONSTRAINT unique_gral_empleado_percep UNIQUE (gral_empleado_id, nom_percep_id);


--
-- Name: unique_gral_usr_suc; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_usr_suc
    ADD CONSTRAINT unique_gral_usr_suc UNIQUE (gral_suc_id, gral_usr_id);


--
-- Name: unique_institucion; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_tc_url
    ADD CONSTRAINT unique_institucion UNIQUE (institucion);


--
-- Name: unique_inv_exi; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_exi
    ADD CONSTRAINT unique_inv_exi UNIQUE (inv_prod_id, inv_alm_id, ano);


--
-- Name: unique_inv_prod_cost_prom; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_prod_cost_prom
    ADD CONSTRAINT unique_inv_prod_cost_prom UNIQUE (inv_prod_id, ano);


--
-- Name: unique_inv_suc_alm; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_suc_alm
    ADD CONSTRAINT unique_inv_suc_alm UNIQUE (almacen_id, sucursal_id);


--
-- Name: unique_nomina_det_nominaid_empleadoid; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_nomina_det
    ADD CONSTRAINT unique_nomina_det_nominaid_empleadoid UNIQUE (fac_nomina_id, gral_empleado_id);


--
-- Name: uniquenomdeduc_clave_emp; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_deduc
    ADD CONSTRAINT uniquenomdeduc_clave_emp UNIQUE (clave, gral_emp_id, borrado_logico);


--
-- Name: uniquenompercep_clave_emp; Type: CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY nom_percep
    ADD CONSTRAINT uniquenompercep_clave_emp UNIQUE (clave, gral_emp_id, borrado_logico);


--
-- Name: fki_12314333; Type: INDEX; Schema: public; Owner: sumar
--

CREATE INDEX fki_12314333 ON gral_suc_pza USING btree (sucursal_id);


--
-- Name: fki_905245; Type: INDEX; Schema: public; Owner: sumar
--

CREATE INDEX fki_905245 ON gral_suc_pza USING btree (plaza_id);


--
-- Name: fki_fk-342352; Type: INDEX; Schema: public; Owner: sumar
--

CREATE INDEX "fki_fk-342352" ON cxc_clie USING btree (pais_id);


--
-- Name: fki_fk123456; Type: INDEX; Schema: public; Owner: sumar
--

CREATE INDEX fki_fk123456 ON gral_plazas USING btree (empresa_id);


--
-- Name: fki_fk76676776; Type: INDEX; Schema: public; Owner: sumar
--

CREATE INDEX fki_fk76676776 ON cxc_clie USING btree (clasif_3);


--
-- Name: 12314333; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_suc_pza
    ADD CONSTRAINT "12314333" FOREIGN KEY (sucursal_id) REFERENCES gral_suc(id);


--
-- Name: 905245; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_suc_pza
    ADD CONSTRAINT "905245" FOREIGN KEY (plaza_id) REFERENCES gral_plazas(id);


--
-- Name: clientes_cliente_tipo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie
    ADD CONSTRAINT clientes_cliente_tipo_id_fkey FOREIGN KEY (clienttipo_id) REFERENCES cxc_clie_clases(id);


--
-- Name: cxp_prov_cxp_prov_zon_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov
    ADD CONSTRAINT cxp_prov_cxp_prov_zon_id_fkey FOREIGN KEY (cxp_prov_zona_id) REFERENCES cxp_prov_zonas(id);


--
-- Name: fk-234243; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_emp
    ADD CONSTRAINT "fk-234243" FOREIGN KEY (pais_id) REFERENCES gral_pais(id);


--
-- Name: fk-342352; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie
    ADD CONSTRAINT "fk-342352" FOREIGN KEY (pais_id) REFERENCES gral_pais(id);


--
-- Name: fk-3457856; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_emp
    ADD CONSTRAINT "fk-3457856" FOREIGN KEY (municipio_id) REFERENCES gral_mun(id);


--
-- Name: fk-354532; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_prod_cost_prom
    ADD CONSTRAINT "fk-354532" FOREIGN KEY (inv_prod_id) REFERENCES inv_prod(id);


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
-- Name: fk123456; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_plazas
    ADD CONSTRAINT fk123456 FOREIGN KEY (empresa_id) REFERENCES gral_emp(id);


--
-- Name: fk76676776; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie
    ADD CONSTRAINT fk76676776 FOREIGN KEY (clasif_3) REFERENCES cxc_clie_clas3(id);


--
-- Name: fk76676777; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie
    ADD CONSTRAINT fk76676777 FOREIGN KEY (clasif_2) REFERENCES cxc_clie_clas2(id);


--
-- Name: fk8970a; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov
    ADD CONSTRAINT fk8970a FOREIGN KEY (clasif_3) REFERENCES cxp_prov_clas3(id);


--
-- Name: fk8970b; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov
    ADD CONSTRAINT fk8970b FOREIGN KEY (clasif_2) REFERENCES cxp_prov_clas2(id);


--
-- Name: fk8970c; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov
    ADD CONSTRAINT fk8970c FOREIGN KEY (clasif_1) REFERENCES cxp_prov_clas1(id);


--
-- Name: fk8970x; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov
    ADD CONSTRAINT fk8970x FOREIGN KEY (dias_credito_id) REFERENCES cxp_prov_credias(id);


--
-- Name: fk_alm00001; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_suc_alm
    ADD CONSTRAINT fk_alm00001 FOREIGN KEY (almacen_id) REFERENCES inv_alm(id);


--
-- Name: fk_clie_descto_clie_id; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxc_clie_descto
    ADD CONSTRAINT fk_clie_descto_clie_id FOREIGN KEY (cxc_clie_id) REFERENCES cxc_clie(id);


--
-- Name: fk_emp_id; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_suc
    ADD CONSTRAINT fk_emp_id FOREIGN KEY (empresa_id) REFERENCES gral_emp(id);


--
-- Name: fk_empleado_00001; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_empleado_percep
    ADD CONSTRAINT fk_empleado_00001 FOREIGN KEY (gral_empleado_id) REFERENCES gral_empleados(id);


--
-- Name: fk_empleado_00002; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_empleado_deduc
    ADD CONSTRAINT fk_empleado_00002 FOREIGN KEY (gral_empleado_id) REFERENCES gral_empleados(id);


--
-- Name: fk_empresa__id; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_cfds_conf
    ADD CONSTRAINT fk_empresa__id FOREIGN KEY (empresa_id) REFERENCES gral_emp(id);


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
-- Name: fk_gral_emp_id; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_cons
    ADD CONSTRAINT fk_gral_emp_id FOREIGN KEY (gral_emp_id) REFERENCES gral_emp(id);


--
-- Name: fk_gral_suc; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_par
    ADD CONSTRAINT fk_gral_suc FOREIGN KEY (gral_suc_id) REFERENCES gral_suc(id);


--
-- Name: fk_gral_suc; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY fac_nomina_par
    ADD CONSTRAINT fk_gral_suc FOREIGN KEY (gral_suc_id) REFERENCES gral_suc(id);


--
-- Name: fk_gral_suc_id; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_emails
    ADD CONSTRAINT fk_gral_suc_id FOREIGN KEY (gral_suc_id) REFERENCES gral_suc(id);


--
-- Name: fk_gral_suc_id; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_cons
    ADD CONSTRAINT fk_gral_suc_id FOREIGN KEY (gral_suc_id) REFERENCES gral_suc(id);


--
-- Name: fk_nom_deduc_00001; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_empleado_deduc
    ADD CONSTRAINT fk_nom_deduc_00001 FOREIGN KEY (nom_deduc_id) REFERENCES nom_deduc(id);


--
-- Name: fk_nom_percep_00001; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY gral_empleado_percep
    ADD CONSTRAINT fk_nom_percep_00001 FOREIGN KEY (nom_percep_id) REFERENCES nom_percep(id);


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
-- Name: fk_suc00001; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_suc_alm
    ADD CONSTRAINT fk_suc00001 FOREIGN KEY (sucursal_id) REFERENCES gral_suc(id);


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
-- Name: inv_exi_inv_alm_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_exi
    ADD CONSTRAINT inv_exi_inv_alm_id_fkey FOREIGN KEY (inv_alm_id) REFERENCES inv_alm(id);


--
-- Name: inv_prod_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_exi
    ADD CONSTRAINT inv_prod_id_fkey FOREIGN KEY (inv_prod_id) REFERENCES inv_prod(id);


--
-- Name: inv_prod_lineas_inv_seccion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_prod_lineas
    ADD CONSTRAINT inv_prod_lineas_inv_seccion_id_fkey FOREIGN KEY (inv_seccion_id) REFERENCES inv_secciones(id);


--
-- Name: inv_prod_tipo_de_producto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_prod
    ADD CONSTRAINT inv_prod_tipo_de_producto_id_fkey FOREIGN KEY (tipo_de_producto_id) REFERENCES inv_prod_tipos(id);


--
-- Name: proveedors_proveedortipo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY cxp_prov
    ADD CONSTRAINT proveedors_proveedortipo_id_fkey FOREIGN KEY (proveedortipo_id) REFERENCES cxp_prov_clases(id);


--
-- Name: yttr; Type: FK CONSTRAINT; Schema: public; Owner: sumar
--

ALTER TABLE ONLY inv_pre
    ADD CONSTRAINT yttr FOREIGN KEY (inv_prod_id) REFERENCES inv_prod(id);


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
