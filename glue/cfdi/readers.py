import os
import xml.sax


class CfdiReader(xml.sax.ContentHandler):
    """
    """
    __ds = None

    def __init__(self):
        pass

    def __call__(self, xml_file_path):
        try:
            self.__reset()
            xml.sax.parse(xml_file_path, self)
            return self.__ds
        except (xml.sax.SAXParseException) as e:
            raise

    def __reset(self):
        self.__ds = {
            'UUID': None,
            'SAT_SEAL': None,
            'CFD_SEAL': None,
            'INCEPTOR_NAME': None,
            'INCEPTOR_RFC': None,
            'INCEPTOR_REGIMEN': None,
            'INCEPTOR_STREET_NUMBER': None,
            'INCEPTOR_STATE': None,
            'INCEPTOR_TOWN': None,
            'INCEPTOR_SETTLEMENT': None,
            'INCEPTOR_STREET': None,
            'INCEPTOR_CP': None,
            'RECEPTOR_NAME': None,
            'RECEPTOR_RFC': None,
            'RECEPTOR_SETTLEMENT': None,
            'RECEPTOR_STREET': None,
            'RECEPTOR_STREET_NUMBER': None,
            'RECEPTOR_TOWN': None,
            'RECEPTOR_CP': None,
            'RECEPTOR_COUNTRY': None,
            'RECEPTOR_STATE': None,
            'ARTIFACTS': [],
            'CFDI_CERT_NUMBER': None,
            'CFDI_DATE': None,
            'CFDI_SERIE': None,
            'CFDI_FOLIO': None,
            'CFDI_SUBTOTAL': None,
            'CFDI_TOTAL': None,
            'CFDI_ORIGIN_PLACE': None,
            'MONEY_EXCHANGE': None,
            'METODO_PAGO' : None,
            'FORMA_PAGO': None,
            'STAMP_DATE': None,
            'SAT_CERT_NUMBER': None,
            'TAXES': { 
                'RET': {
                    'DETAILS': [],
                    'TOTAL': 0
                },
                'TRAS': {
                    'DETAILS': [],
                    'TOTAL': 0
                }
            }
        }

    def startElement(self, name, attrs):

            if name == "tfd:TimbreFiscalDigital":
                for (k, v) in attrs.items():
                    if k == "UUID":
                        self.__ds['UUID'] = v
                    if k == "selloSAT":
                        self.__ds['SAT_SEAL'] = v
                    if k == "selloCFD":
                        self.__ds['CFD_SEAL'] = v
                    if k == "noCertificadoSAT":
                        self.__ds['SAT_CERT_NUMBER'] = v
                    if k == "FechaTimbrado":
                        self.__ds['STAMP_DATE'] = v
            
            if name == "cfdi:Emisor":
                for (k, v) in attrs.items():
                    if k == "nombre":
                        self.__ds['INCEPTOR_NAME'] = v
                    if k == "rfc":
                        self.__ds['INCEPTOR_RFC'] = v

            if name == "cfdi:RegimenFiscal":
                for (k, v) in attrs.items():
                    if k == "Regimen":
                        self.__ds['INCEPTOR_REGIMEN'] = v

            if name == "cfdi:DomicilioFiscal":
                for (k, v) in attrs.items():
                    if k == "calle":
                        self.__ds['INCEPTOR_STREET'] = v
                    if k == "noExterior":
                        self.__ds['INCEPTOR_STREET_NUMBER'] = v
                    if k == "colonia":
                        self.__ds['INCEPTOR_SETTLEMENT'] = v
                    if k == "estado":
                        self.__ds['INCEPTOR_STATE'] = v
                    if k == "municipio":
                        self.__ds['INCEPTOR_TOWN'] = v
                    if k == "codigoPostal":
                        self.__ds['INCEPTOR_CP'] = v

            if name == "cfdi:Domicilio":
                for (k, v) in attrs.items():
                    if k == "noInterior":
                        self.__ds['RECEPTOR_STREET_NUMBER'] = v
                    if k == "estado":
                        self.__ds['RECEPTOR_STATE'] = v
                    if k == "pais":
                        self.__ds['RECEPTOR_COUNTRY'] = v
                    if k == "codigoPostal":
                        self.__ds['RECEPTOR_CP'] = v
                    if k == "municipio":
                        self.__ds['RECEPTOR_TOWN'] = v
                    if k == "colonia":
                        self.__ds['RECEPTOR_SETTLEMENT'] = v
                    if k == "calle":
                        self.__ds['RECEPTOR_STREET'] = v

            if name == "cfdi:Receptor":
                for (k, v) in attrs.items():
                    if k == "nombre":
                        self.__ds['RECEPTOR_NAME'] = v
                    if k == "rfc":
                        self.__ds['RECEPTOR_RFC'] = v

            if name == "cfdi:Comprobante":
                for (k, v) in attrs.items():
                    if k == "total":
                        self.__ds['CFDI_TOTAL'] = v
                    if k == "subTotal":
                        self.__ds['CFDI_SUBTOTAL'] = v
                    if k == "TipoCambio":
                        self.__ds['MONEY_EXCHANGE'] = v
                    if k == "metodoDePago":
                        self.__ds['METODO_PAGO'] = v
                    if k == "formaDePago":
                        self.__ds['FORMA_PAGO'] = v
                    if k == "serie":
                        self.__ds['CFDI_SERIE'] = v
                    if k == "folio":
                        self.__ds['CFDI_FOLIO'] = v
                    if k == "fecha":
                        self.__ds['CFDI_DATE'] = v
                    if k == "noCertificado":
                        self.__ds['CFDI_CERT_NUMBER'] = v
                    if k == "LugarExpedicion":
                        self.__ds['CFDI_ORIGIN_PLACE'] = v

            if name == "cfdi:Concepto":
                c = {}
                for (k, v) in attrs.items():
                    if k == "cantidad":
                        c[k.upper()] = v
                    if k == "descripcion":
                        c[k.upper()] = v
                    if k == "importe":
                        c[k.upper()] = v
                    if k == "noIdentificacion":
                        c[k.upper()] = v
                    if k == "unidad":
                        c[k.upper()] = v
                    if k == "valorUnitario":
                        c[k.upper()] = v
                self.__ds['ARTIFACTS'].append(c)

            if name == "cfdi:Impuestos":
                for (k, v) in attrs.items():
                    if k == "totalImpuestosRetenidos":
                        self.__ds['TAXES']['RET']['TOTAL'] = v
                    if k == "totalImpuestosTrasladados":
                        self.__ds['TAXES']['TRAS']['TOTAL'] = v

            if name == "cfdi:Retencion":
                c = {}
                for (k, v) in attrs.items():
                    if k == "importe":
                        c[k.upper()] = v
                    if k == "impuesto":
                        c[k.upper()] = v
                self.__ds['TAXES']['RET']['DETAILS'].append(c)


            if name == "cfdi:Traslado":
                c = {}
                for (k, v) in attrs.items():
                    if k == "importe":
                        c[k.upper()] = v
                    if k == "impuesto":
                        c[k.upper()] = v
                    if k == "tasa":
                        c[k.upper()] = v
                self.__ds['TAXES']['TRAS']['DETAILS'].append(c)
