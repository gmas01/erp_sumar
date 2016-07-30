/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package com.agnux.kemikal.controllers;
import com.agnux.cfd.v2.ArchivoInformeMensual;
import com.agnux.cfd.v2.Base64Coder;
import com.agnux.cfdi.BeanCancelaCfdi;
import com.agnux.cfdi.BeanFromCfdiXml;
import com.agnux.common.helpers.FileHelper;
import com.agnux.common.helpers.StringHelper;
import com.agnux.common.obj.DataPost;
import com.agnux.common.obj.ResourceProject;
import com.agnux.common.obj.UserSessionData;
import com.agnux.kemikal.interfacedaos.FacturasInterfaceDao;
import com.agnux.kemikal.interfacedaos.GralInterfaceDao;
import com.agnux.kemikal.interfacedaos.HomeInterfaceDao;
import java.io.BufferedInputStream;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.URISyntaxException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.web.servlet.ModelAndView;
import org.springframework.ui.Model;
import org.springframework.util.FileCopyUtils;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.SessionAttributes;

/**
 * @author gpmarsan@gmail.com
 * Noe Martinez 
 * 28/mayo/2013
 * En esta fecha se separo en dos aplicativos(antes solo era Consulta Cancelacion)
 */
@Controller
@SessionAttributes({"user"})
@RequestMapping("/faccancelacion/")
public class FacCancelacionController {
    ResourceProject resource = new ResourceProject();
    private static final Logger log  = Logger.getLogger(FacCancelacionController.class.getName());
    
    
    @Autowired
    @Qualifier("daoGral")
    private GralInterfaceDao gralDao;
    
    
    @Autowired
    @Qualifier("daoFacturas")
    private FacturasInterfaceDao facdao;
    
    @Autowired
    @Qualifier("daoHome")
    private HomeInterfaceDao HomeDao;
    
    
    @Autowired
    @Qualifier("beanCancelaCfdi")
    BeanCancelaCfdi bcancelafdi;
    
    public BeanCancelaCfdi getBcancelafdi() {
        return bcancelafdi;
    }
    
    public HomeInterfaceDao getHomeDao() {
        return HomeDao;
    }
    
    public GralInterfaceDao getGralDao() {
        return gralDao;
    }
    
    public FacturasInterfaceDao getFacdao() {
        return facdao;
    }
    
    @RequestMapping(value="/startup.agnux")
    public ModelAndView startUp(HttpServletRequest request, HttpServletResponse response, 
            @ModelAttribute("user") UserSessionData user
            )throws ServletException, IOException {
        
        log.log(Level.INFO, "Ejecutando starUp de {0}", FacCancelacionController.class.getName());
        LinkedHashMap<String,String> infoConstruccionTabla = new LinkedHashMap<String,String>();
        
        infoConstruccionTabla.put("id", "Acciones:70");
        infoConstruccionTabla.put("serie_folio", "Factura:80");
        infoConstruccionTabla.put("cliente", "Cliente:300");
        infoConstruccionTabla.put("total", "Monto:90");
        infoConstruccionTabla.put("moneda", "Moneda:60");
        infoConstruccionTabla.put("fecha_facturacion","Fecha&nbsp;Exp.:80");
        infoConstruccionTabla.put("fecha_venc","Fecha&nbsp;Ven.:80");
        infoConstruccionTabla.put("folio_pedido","Pedido:80");
        infoConstruccionTabla.put("oc","O.C.:80");
        infoConstruccionTabla.put("estado", "Estado:80");
        infoConstruccionTabla.put("fecha_pago","Fecha&nbsp;Pago:80");
        
        ModelAndView x = new ModelAndView("faccancelacion/startup", "title", "Cancelaci&oacute;n de Facturas");
        
        x = x.addObject("layoutheader", resource.getLayoutheader());
        x = x.addObject("layoutmenu", resource.getLayoutmenu());
        x = x.addObject("layoutfooter", resource.getLayoutfooter());
        x = x.addObject("grid", resource.generaGrid(infoConstruccionTabla));
        x = x.addObject("url", resource.getUrl(request));
        x = x.addObject("username", user.getUserName());
        x = x.addObject("empresa", user.getRazonSocialEmpresa());
        x = x.addObject("sucursal", user.getSucursal());
        
        String userId = String.valueOf(user.getUserId());
        
        //System.out.println("id_de_usuario: "+userId);
        
        String codificado = Base64Coder.encodeString(userId);
        
        //id de usuario codificado
        x = x.addObject("iu", codificado);
        
        return x;
    }
    
    
    
    
    @RequestMapping(value="/getAllFacturas.json", method = RequestMethod.POST)
    public @ResponseBody HashMap<String,ArrayList<HashMap<String, Object>>> getAllFacturasacturasJson(
           @RequestParam(value="orderby", required=true) String orderby,
           @RequestParam(value="desc", required=true) String desc,
           @RequestParam(value="items_por_pag", required=true) int items_por_pag,
           @RequestParam(value="pag_start", required=true) int pag_start,
           @RequestParam(value="display_pag", required=true) String display_pag,
           @RequestParam(value="input_json", required=true) String input_json,
           @RequestParam(value="cadena_busqueda", required=true) String cadena_busqueda,
           @RequestParam(value="iu", required=true) String id_user_cod,
       Model modcel) {
        
        HashMap<String,ArrayList<HashMap<String, Object>>> jsonretorno = new HashMap<String,ArrayList<HashMap<String, Object>>>();
        HashMap<String,String> has_busqueda = StringHelper.convert2hash(StringHelper.ascii2string(cadena_busqueda));
        
        //Aplicativo Cancelacion de Facturas
        Integer app_selected = 36;
        
        //decodificar id de usuario
        Integer id_usuario = Integer.parseInt(Base64Coder.decodeString(id_user_cod));
        
        //variables para el buscador
        String factura = "%"+StringHelper.isNullString(String.valueOf(has_busqueda.get("factura")))+"%";
        String cliente = "%"+StringHelper.isNullString(String.valueOf(has_busqueda.get("cliente")))+"%";
        String fecha_inicial = ""+StringHelper.isNullString(String.valueOf(has_busqueda.get("fecha_inicial")))+"";
        String fecha_final = ""+StringHelper.isNullString(String.valueOf(has_busqueda.get("fecha_final")))+"";
        String codigo = "%"+StringHelper.isNullString(String.valueOf(has_busqueda.get("codigo")))+"%";
        String producto = "%"+StringHelper.isNullString(String.valueOf(has_busqueda.get("producto")))+"%";
        String agente = ""+StringHelper.isNullString(String.valueOf(has_busqueda.get("agente")))+"";
        
        String data_string = app_selected+"___"+id_usuario+"___"+factura+"___"+cliente+"___"+fecha_inicial+"___"+fecha_final+"___"+codigo+"___"+producto+"___"+agente;
        
        //obtiene total de registros en base de datos, con los parametros de busqueda
        int total_items = this.getFacdao().countAll(data_string);
        
        //calcula el total de paginas
        int total_pags = resource.calculaTotalPag(total_items,items_por_pag);
        
        //variables que necesita el datagrid, para no tener que hacer uno por cada aplicativo
        DataPost dataforpos = new DataPost(orderby, desc, items_por_pag, pag_start, display_pag, input_json, cadena_busqueda,total_items,total_pags, id_user_cod);
        
        int offset = resource.__get_inicio_offset(items_por_pag, pag_start);
        
        //obtiene los registros para el grid, de acuerdo a los parametros de busqueda
        jsonretorno.put("Data", this.getFacdao().getFacturas_PaginaGrid(data_string, offset, items_por_pag, orderby, desc));
        //obtiene el hash para los datos que necesita el datagrid
        jsonretorno.put("DataForGrid", dataforpos.formaHashForPos(dataforpos));
        
        return jsonretorno;
    }
    
    
    //obtiene los Agentes para el Buscador pricipal del Aplicativo
    @RequestMapping(method = RequestMethod.POST, value="/getAgentesParaBuscador.json")
    public @ResponseBody HashMap<String,ArrayList<HashMap<String, Object>>> getAgentesParaBuscador(
            @RequestParam(value="iu", required=true) String id_user_cod,
            Model model
        ) {
        
        HashMap<String,ArrayList<HashMap<String, Object>>> jsonretorno = new HashMap<String,ArrayList<HashMap<String, Object>>>();
        HashMap<String, String> userDat = new HashMap<String, String>();
        ArrayList<HashMap<String, Object>> agentes = new ArrayList<HashMap<String, Object>>();
        
        //decodificar id de usuario
        Integer id_usuario = Integer.parseInt(Base64Coder.decodeString(id_user_cod));
        userDat = this.getHomeDao().getUserById(id_usuario);
        Integer id_empresa = Integer.parseInt(userDat.get("empresa_id"));
        Integer id_sucursal = Integer.parseInt(userDat.get("sucursal_id"));
        
        agentes = this.getFacdao().getFactura_Agentes(id_empresa, id_sucursal);
        
        jsonretorno.put("Agentes", agentes);
        return jsonretorno;
    }
    
    
    @RequestMapping(method = RequestMethod.POST, value="/getFactura.json")
    public @ResponseBody HashMap<String,ArrayList<HashMap<String, Object>>> getFacturaJson(
            @RequestParam(value="id_factura", required=true) String id_factura,
            @RequestParam(value="iu", required=true) String id_user,
            Model model
        ) {
        
        log.log(Level.INFO, "Ejecutando getFacturaJson de {0}", FacCancelacionController.class.getName());
        HashMap<String,ArrayList<HashMap<String, Object>>> jsonretorno = new HashMap<String,ArrayList<HashMap<String, Object>>>();
        ArrayList<HashMap<String, Object>> datosFactura = new ArrayList<HashMap<String, Object>>();
        ArrayList<HashMap<String, Object>> datosGrid = new ArrayList<HashMap<String, Object>>();
        ArrayList<HashMap<String, Object>> valorIva = new ArrayList<HashMap<String, Object>>();
        ArrayList<HashMap<String, Object>> tipoCambioActual = new ArrayList<HashMap<String, Object>>();
        HashMap<String, Object> tc = new HashMap<String, Object>();
        HashMap<String, String> userDat = new HashMap<String, String>();
        
        //Decodificar id de usuario
        Integer id_usuario = Integer.parseInt(Base64Coder.decodeString(id_user));
        
        userDat = this.getHomeDao().getUserById(id_usuario);
        
        Integer id_empresa = Integer.parseInt(userDat.get("empresa_id"));
        Integer id_sucursal = Integer.parseInt(userDat.get("sucursal_id"));
        
        if( !id_factura.equals("0")  ){
            datosFactura = this.getFacdao().getFactura_Datos(Integer.parseInt(id_factura));
            datosGrid = this.getFacdao().getFactura_DatosGrid(Integer.parseInt(id_factura));
        }
        
        valorIva= this.getFacdao().getValoriva(id_sucursal);
        tc.put("tipo_cambio", StringHelper.roundDouble(this.getFacdao().getTipoCambioActual(), 4)) ;
        tipoCambioActual.add(0,tc);
        
        jsonretorno.put("Datos", datosFactura);
        jsonretorno.put("datosGrid", datosGrid);
        jsonretorno.put("iva", valorIva);
        jsonretorno.put("Tc", tipoCambioActual);
        jsonretorno.put("Monedas", this.getFacdao().getFactura_Monedas());
        jsonretorno.put("Vendedores", this.getFacdao().getFactura_Agentes(id_empresa, id_sucursal));
        jsonretorno.put("Condiciones", this.getFacdao().getFactura_DiasDeCredito());
        jsonretorno.put("MetodosPago", this.getFacdao().getMetodosPago(id_empresa));
        
        return jsonretorno;
    }
    
    
    
    
    
    
    //obtiene datos para generador  de informe
    @RequestMapping(method = RequestMethod.POST, value="/datos_generador_informe.json")
    public @ResponseBody HashMap<String,ArrayList<HashMap<String, Integer>>> get_datos_generador_informeJson(Model model) {
        HashMap<String,ArrayList<HashMap<String, Integer>>> jsonretorno = new HashMap<String,ArrayList<HashMap<String, Integer>>>();
        
        jsonretorno.put("anioinforme", this.getFacdao().getFactura_AnioInforme());
        return jsonretorno;
    }
    
    
    
    //obtiene los tipos de cancelacion
    @RequestMapping(method = RequestMethod.POST, value="/getTiposCancelacion.json")
    public @ResponseBody HashMap<String,Object> getTiposCancelacionJson(
            @RequestParam(value="identificador", required=true) Integer identificador,
            @RequestParam(value="iu", required=true) String id_user,
            Model model
        ) {
        log.log(Level.INFO, "Ejecutando getTiposCancelacionJson de {0}", FacCancelacionController.class.getName());
        HashMap<String,Object> jsonretorno = new HashMap<String,Object>();
        
        HashMap<String, String> userDat = new HashMap<String, String>();
        
        Integer app_selected = 36;
        //Decodificar id de usuario
        Integer id_usuario = Integer.parseInt(Base64Coder.decodeString(id_user));
        
        userDat = this.getHomeDao().getUserById(id_usuario);
        
        Integer id_empresa = Integer.parseInt(userDat.get("empresa_id"));
        //Integer id_sucursal = Integer.parseInt(userDat.get("sucursal_id"));
        
        jsonretorno.put("Tipos", this.getFacdao().getTiposCancelacion());
        jsonretorno.put("TMov", this.getFacdao().getCtb_TiposDeMovimiento(id_empresa, app_selected));
        
        return jsonretorno;
    }
    

    
    
    
    
    
    
    //cancelacion de facturas
    @RequestMapping(method = RequestMethod.POST, value="/cancelar_factura.json")
    public @ResponseBody HashMap<String, String> getCancelarFactura(
            @RequestParam(value="id_factura", required=true) Integer id_factura,
            @RequestParam(value="tipo_cancelacion", required=true) Integer tipo_cancelacion,
            @RequestParam(value="tmov", required=false) String tmov,
            @RequestParam(value="motivo", required=true) String motivo_cancelacion,
            @RequestParam(value="iu", required=true) String id_user,
            Model model
        ) {
        
        HashMap<String, String> userDat = new HashMap<String, String>();
        HashMap<String, String> jsonretorno = new HashMap<String, String>();
        HashMap<String, String> validacion = new HashMap<String, String>();
        Integer id_usuario=0;//aqui va el id del usuario
        
        //decodificar id de usuario
        id_usuario = Integer.parseInt(Base64Coder.decodeString(id_user));
        //System.out.println("id_usuario: "+id_usuario);
        userDat = this.getHomeDao().getUserById(id_usuario);
        Integer id_empresa = Integer.parseInt(userDat.get("empresa_id"));
        Integer id_sucursal = Integer.parseInt(userDat.get("sucursal_id"));
        
        //Aplicativo Cancelacion de Facturas
        Integer app_selected = 36;
        String command_selected = "cancelacion";
        String extra_data_array = "'sin datos'";
        String succcess = "false";
        String serie_folio="";
        String refId = "";
        String tipo_facturacion="";
        String valorRespuesta="false";
        String msjRespuesta="";
        
        tmov = StringHelper.verificarSelect(tmov);
                
        String data_string = app_selected +"___"+ command_selected +"___"+ id_usuario +"___"+ id_factura +"___"+ tipo_cancelacion +"___"+ motivo_cancelacion.toUpperCase() +"___"+ tmov;
        
        validacion = this.getFacdao().selectFunctionValidateAaplicativo(data_string,app_selected,extra_data_array);
        
        if(String.valueOf(validacion.get("success")).equals("true")){
            
            tipo_facturacion = this.getFacdao().getTipoFacturacion(id_empresa);
            tipo_facturacion = String.valueOf(tipo_facturacion);
            
            //Obtener el numero del PAC para el Timbrado de la Factura
            String noPac = this.getFacdao().getNoPacFacturacion(id_empresa);
            
            //Obtener el Ambiente de Facturacion PRUEBAS ó PRODUCCION, solo aplica para Facturacion por Timbre FIscal(cfditf)
            String ambienteFac = this.getFacdao().getAmbienteFacturacion(id_empresa);
            
            System.out.println("Tipo::"+tipo_facturacion+" | noPac::"+noPac+" | Ambiente::"+ambienteFac);
            
            serie_folio = this.getFacdao().getSerieFolioFactura(id_factura, id_empresa);
            refId = this.getFacdao().getRefIdFactura(id_factura, id_empresa);
            
            
            if(tipo_facturacion.equals("cfd") ){
                succcess = this.getFacdao().selectFunctionForFacAdmProcesos(data_string, extra_data_array);//llamada al procedimiento para cancelacion
                
                if(String.valueOf(succcess).equals("true")){
                    valorRespuesta="true";
                    msjRespuesta="La Factura: "+serie_folio+", fue cancelada con &eacute;xito.";
                }else{
                    valorRespuesta="false";
                    msjRespuesta="La factura "+serie_folio+", no fue posible cancelar.\nIntente de nuevo.";
                }
            }
            
            if(tipo_facturacion.equals("cfdi")){
                
                //Pac 0=Sin PAC, 1=Diverza, 2=ServiSim
                if(!noPac.equals("0") && !noPac.equals("2")){
                    //Solo se permite Cancelar Factura por Conector Fiscal con Diverza
                
                    File toFile = new File(this.getGralDao().getCfdiSolicitudesDir() + "out/"+refId+".xml");
                    //System.out.println("FicheroXML: "+this.getGralDao().getCfdiSolicitudesDir() + "out/"+serie_folio+".xml");

                    if (toFile.exists()) {
                        //si el existe el xml, se procede a la cancelacion
                        succcess = this.getFacdao().selectFunctionForFacAdmProcesos(data_string, extra_data_array);

                        //tipo facturacion CFDI. Generar txt para buzon fiscal
                        if(String.valueOf(succcess).equals("true")){

                            HashMap<String, String> data = new HashMap<String, String>();
                            //serie_folio = succcess.split(":")[0];
                            
                            String directorioSolicitudesCfdiOut=this.getGralDao().getCfdiSolicitudesDir() + "out/"+refId+".xml";
                            BeanFromCfdiXml pop = new BeanFromCfdiXml(directorioSolicitudesCfdiOut);
                            
                            data.put("uuid", pop.getUuid());
                            data.put("emisor_rfc", pop.getEmisor_rfc());
                            data.put("receptor_rfc", pop.getReceptor_rfc());
                            
                            //generar archivo de texto para cfdi
                            this.getBcancelafdi().init(data, serie_folio);
                            this.getBcancelafdi().start();
                            
                            System.out.println("serie_folio:"+serie_folio + "    Cancelado:"+succcess.split(":")[1]);
                            valorRespuesta="true";
                            msjRespuesta="La Factura: "+serie_folio+", fue cancelada con &eacute;xito.";
                        
                        }else{
                            valorRespuesta="false";
                            msjRespuesta="La factura "+serie_folio+", no fue posible cancelar.\nIntente de nuevo.";
                        }
                        
                    }else{                        
                        valorRespuesta="false";
                        msjRespuesta="No fue posible cancelar la Factura "+serie_folio+". No se encuentra el archivo XML.";
                    }
                }else{
                    valorRespuesta="false";
                    msjRespuesta="No se puede Cancelar por Conector Fiscal con el PAC actual.\nVerifique la configuraci&oacute;n del tipo de Facturaci&oacute;n y del PAC.";
                }
            }else{
                if(tipo_facturacion.equals("cfditf") ){
                    try {
                        
                        //Pac 0=Sin PAC, 1=Diverza, 2=ServiSim
                        if(!String.valueOf(noPac).equals("0")){
                            //Solo se permite Cancelar Factura con Diverza y ServiSim
                            
                            //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
                            //aqui inicia request al webservice
                            //:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
                            String rfcEmpresaEmisora = this.getGralDao().getRfcEmpresaEmisora(id_empresa);
                            String ruta_ejecutable_java = this.getGralDao().getJavaVmDir(id_empresa, id_sucursal);
                            //String ruta_ejecutable_java = "/home/agnux/jdk/bin/java";
                            String ruta_jarWebService = this.getGralDao().getCfdiTimbreJarWsDir()+"wscli.jar";
                            String ruta_fichero_llave_pfx = this.getGralDao().getSslDir() + rfcEmpresaEmisora+ "/" +this.getGralDao().getFicheroPfxTimbradoCfdi(id_empresa,id_sucursal) ;
                            String password_pfx = this.getGralDao().getPasswdFicheroPfxTimbradoCfdi(id_empresa, id_sucursal);
                            String ruta_java_almacen_certificados = this.getGralDao().getJavaRutaCacerts(id_empresa, id_sucursal);
                            //String ruta_java_almacen_certificados = "/home/agnux/jdk/jre/lib/security/cacerts";
                            
                            String rutaCanceladosDir = this.getGralDao().getCfdiTimbreCanceladosDir();
                            String RutaficheroXml = this.getGralDao().getCfdiTimbreEmitidosDir() + rfcEmpresaEmisora +"/"+ refId+".xml";
                            BeanFromCfdiXml pop = new BeanFromCfdiXml(RutaficheroXml);
                            
                            String uuid = pop.getUuid();
                            String emisor_rfc = pop.getEmisor_rfc();
                            String receptor_rfc = pop.getReceptor_rfc();
                            String tipo_peticion = "cancelacfdi";
                            
                            String str_execute="";
                            
                            //Cancelacion con DIVERZA
                            if(String.valueOf(noPac).equals("1")){
                                /*
                                //Datos para cancelacion
                                args[0] = PAC proveedor
                                args[1] = tipo de ambiente(pruebas, produccion)
                                args[2] = tipo_peticion
                                args[3] = FicheroPfxTimbradoCfdi
                                args[4] = PasswdFicheroPfxTimbradoCfdi
                                args[5] = JavaVmDir
                                args[6] = getRfc_emisor
                                args[7] = getRfc_receptor
                                args[8] = uuid
                                args[9] = DirCancelados
                                args[10] = serie_folio
                                 */
                                
                                str_execute = ruta_ejecutable_java+" -jar "+ruta_jarWebService+" "+noPac+" "+ambienteFac+" "+tipo_peticion+" "+ruta_fichero_llave_pfx+" "+password_pfx+" "+ruta_java_almacen_certificados+" "+emisor_rfc+" "+receptor_rfc+" "+uuid+" "+rutaCanceladosDir+" "+serie_folio;
                            }
                            
                            //Cancelacion con SERVISIM
                            if(String.valueOf(noPac).equals("2")){
                                
                                /*
                                //Datos para Cancelacion
                                args[0] = PAC proveedor
                                args[1] = tipo de ambiente(pruebas, produccion)
                                args[2] = tipo_peticion(cancelacion, timbrado)
                                args[3] = Usuario
                                args[4] = Password
                                args[5] = uuid
                                args[6] = rfcEmisor
                                args[7] = serieFolio
                                args[8] = dirCancelados
                                */
                                
                                String usuario = this.getGralDao().getUserContrato(id_empresa, id_sucursal);
                                String contrasena = this.getGralDao().getPasswordUserContrato(id_empresa, id_sucursal);
                                
                                //aqui se forma la cadena con los parametros que se le pasan a jar
                                str_execute = ruta_ejecutable_java+" -jar "+ruta_jarWebService+" "+noPac+" "+ambienteFac+" "+tipo_peticion+" "+usuario+" "+contrasena+" "+uuid+" "+emisor_rfc+" "+serie_folio+" "+rutaCanceladosDir;
                            }
                            
                            
                            System.out.println("str_execute: "+str_execute);
                            Process resultado = null; 
                            
                            resultado = Runtime.getRuntime().exec(str_execute);
                            
                            InputStream myInputStream=null;
                            myInputStream= resultado.getInputStream();
                            
                            BufferedReader reader = new BufferedReader(new InputStreamReader(myInputStream));
                            StringBuilder sb = new StringBuilder();
                            String line = null;
                            while ((line = reader.readLine()) != null) {
                                sb.append(line);
                            }
                            myInputStream.close();
                            
                            System.out.println("Resultado: "+sb.toString());
                            String arrayResult[] = sb.toString().split("___");
                            
                            //Toma el valor true o false
                            valorRespuesta = arrayResult[0];
                            
                            //Toma el mensaje
                            msjRespuesta = arrayResult[1];
                            
                            if(String.valueOf(valorRespuesta).equals("true")){
                                succcess = this.getFacdao().selectFunctionForFacAdmProcesos(data_string, extra_data_array);
                                if(String.valueOf(succcess).equals("true")){
                                    HashMap<String, String> data = new HashMap<String, String>();
                                    //serie_folio = succcess.split(":")[0];
                                    //System.out.println("serie_folio:"+serie_folio + "    Cancelado:"+succcess.split(":")[1]);
                                }
                            }
                            
                            jsonretorno.put("success", succcess);
                        }else{
                            valorRespuesta="false";
                            msjRespuesta="No se puede Cancelar la Factura con el PAC actual.\nVerifique la configuraci&oacute;n del tipo de Facturaci&oacute;n y del PAC.";
                        }
                        
                    } catch (IOException ex) {
                        valorRespuesta="false";
                        msjRespuesta="No se pudo cancelar la Factura.";
                        Logger.getLogger(FacCancelacionController.class.getName()).log(Level.SEVERE, null, ex);
                    }
                }//Termina CANCELACION cfditf
                else{
                    jsonretorno.put("success", succcess);
                    valorRespuesta="false";
                    msjRespuesta="No se ha configurado el tipo de facturacion.";
                }
            }
            
            jsonretorno.put("success", String.valueOf(validacion.get("success")));
        }else{
            jsonretorno.put("success", "false");
            valorRespuesta="false";
            String resultValidacion[] = validacion.get("success").split("___");
            msjRespuesta=resultValidacion[1];
        }
        
        System.out.println("valor_retorno:: "+ jsonretorno.get("success"));
        jsonretorno.put("valor",valorRespuesta);
        jsonretorno.put("msj",msjRespuesta);
        
        System.out.println("valorRespuesta: "+String.valueOf(valorRespuesta));
        System.out.println("msjRespuesta: "+String.valueOf(msjRespuesta));
        
        return jsonretorno;
    }
    
    
    
    
    
    
    
    //Reporte Mensual SAT (Genera txt)
    @RequestMapping(value = "/get_genera_txt_reporte_mensual_sat/{month}/{year}/{iu}/out.json", method = RequestMethod.GET ) 
    public ModelAndView get_genera_txt_reporte_mensual_sat(
            @PathVariable("year") String year, 
            @PathVariable("month") String month,
            @PathVariable("iu") String id_user,
            HttpServletRequest request, 
            HttpServletResponse response, 
            Model model) throws ServletException, IOException, URISyntaxException {
        
        HashMap<String, String> userDat = new HashMap<String, String>();
        
        //decodificar id de usuario
        Integer id_usuario = Integer.parseInt(Base64Coder.decodeString(id_user));
        //System.out.println("id_usuario: "+id_usuario);
        
        userDat = this.getHomeDao().getUserById(id_usuario);
        Integer id_empresa = Integer.parseInt(userDat.get("empresa_id"));
        
        ArchivoInformeMensual aim = new ArchivoInformeMensual();
        
        String nombre_txt = aim.generaNombreArchivoInformeMensual("1",this.getGralDao().getRfcEmpresaEmisora(id_empresa),month,year,"txt");
        String fileout = this.getGralDao().getTmpDir() + nombre_txt;
         File toFile = new File(fileout);
    	if (toFile.exists()) {
            //si el archivo ya esxiste, es eliminado
            toFile.delete();
        }
        
        
        ArrayList<HashMap<String, Object>> valor_emitidos = this.getFacdao().getComprobantesActividadPorMes(year, month,id_empresa);
        
        for(HashMap<String,Object> iteradorX : valor_emitidos){
            String renglon = aim.generarRegistroPorRenglonParaArchivoInformeMensual(
                    String.valueOf(iteradorX.get("rfc_cliente")),
                    String.valueOf(iteradorX.get("serie")),
                    String.valueOf(iteradorX.get("folio_del_comprobante_fiscal")),
                    String.valueOf(iteradorX.get("numero_de_aprobacion")),
                    String.valueOf(iteradorX.get("momento_expedicion")),
                    String.valueOf(iteradorX.get("monto_de_la_operacion")),
                    String.valueOf(iteradorX.get("monto_del_impuesto")),
                    String.valueOf(iteradorX.get("estado_del_comprobante")),
                    String.valueOf(iteradorX.get("efecto_de_comprobante")),
                    String.valueOf(iteradorX.get("pedimento")),
                    String.valueOf(iteradorX.get("fecha_de_pedimento")),
                    String.valueOf(iteradorX.get("aduana")),
                    String.valueOf(iteradorX.get("anoaprovacion")));
            
            if(!renglon.isEmpty()){
                //FileHelper.addText2File(System.getProperty("java.io.tmpdir")+ "/" + nombre_txt,renglon);
                FileHelper.addText2File(this.getGralDao().getTmpDir() + nombre_txt,renglon);
            }
	}
        
        //String fileout = System.getProperty("java.io.tmpdir")+ "/" + nombre_txt;
        
        System.out.println("Recuperando archivo: " + fileout);
        
        File file = new File(fileout);
        if (file.exists()==false){
            System.out.println("No hay facturas en este mes");
            FileHelper.addText2File(this.getGralDao().getTmpDir() + nombre_txt,"");
        }
        
        int size = (int) file.length(); // Tamaño del archivo
        BufferedInputStream bis = new BufferedInputStream(new FileInputStream(file));
        response.setBufferSize(size);
        response.setContentLength(size);
        response.setContentType("text/plain");
        response.setHeader("Content-Disposition","attachment; filename=\"" + file.getCanonicalPath() +"\"");
        FileCopyUtils.copy(bis, response.getOutputStream());
        response.flushBuffer();
        
        return null;
    }
    
    
    
    

}
