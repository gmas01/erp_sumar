from reportlab.platypus import BaseDocTemplate, PageTemplate, Frame, Table, TableStyle, Paragraph, Spacer, Image
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.lib.units import cm 
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.pdfgen import canvas

import lxml.etree as ET
import os
import psycopg2
import psycopg2.extras
from utils.numbertrans import transnum_spa
from utils.numberformat import currency_format
from cfdi.readers import CfdiReader
import re


class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        canvas.Canvas.__init__(self, *args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        """add page info to each page (page x of y)"""
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_number(num_pages)
            canvas.Canvas.showPage(self)
        canvas.Canvas.save(self)

    def draw_page_number(self, page_count):
        width, height = letter
        self.setFont("Helvetica", 7)
        self.drawCentredString(width / 2.0, 0.65*cm,
            "Pagina %d de %d" % (self._pageNumber, page_count))


def __load_cove(conn, serie_folio):

    __COVE_SQL = """SELECT fac_docs.serie_folio,  inv_prod.sku,
        fac_docs_detalles.cantidad, inv_prod_cove.cove_lts,
        inv_prod_cove.cove_kgs,
        (fac_docs_detalles.cantidad * inv_prod_cove.cove_lts) as mul_lit,
        (fac_docs_detalles.cantidad * inv_prod_cove.cove_kgs) as mul_kgs
        FROM fac_docs
        JOIN fac_docs_detalles ON fac_docs.id = fac_docs_detalles.fac_doc_id    
        JOIN inv_prod_cove ON inv_prod_cove.inv_prod_id = fac_docs_detalles.inv_prod_id
        JOIN inv_prod ON inv_prod_cove.inv_prod_id = inv_prod.id
        WHERE fac_docs_detalles.inv_prod_id=inv_prod_cove.inv_prod_id AND
        fac_docs.serie_folio like"""

    cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
    try:
        q = "{0} '{1}'".format(__COVE_SQL, serie_folio)
        cur.execute(q)
        rows = cur.fetchall()
        if len(rows) > 0:
            return rows
        else:
            raise DocBuilderStepError('There is not cove data')
    except psycopg2.Error as e:
        raise DocBuilderStepError("an error happen when loading cove data")


def __load_extra_info(conn, serie_folio):

    __EXTRA_INF_SQL = """SELECT  fac_docs.orden_compra AS purchase_number,
        cxc_agen.nombre AS sales_man,
        cxc_clie_credias.descripcion AS payment_constraint,
        (CASE
             WHEN fac_docs.fecha_vencimiento IS NULL THEN ''
             ELSE to_char(fac_docs.fecha_vencimiento,'dd/mm/yyyy')
        END) AS payment_date,
        upper(gral_mon.descripcion) AS currency_name,
        gral_mon.descripcion_abr AS currency_abr,
        cxc_clie.numero_control AS customer_control_id
        FROM fac_docs
        LEFT JOIN cxc_clie_credias ON cxc_clie_credias.id = fac_docs.terminos_id
        LEFT JOIN gral_mon on gral_mon.id = fac_docs.moneda_id
        JOIN cxc_agen ON cxc_agen.id =  fac_docs.cxc_agen_id
        JOIN cxc_clie ON fac_docs.cxc_clie_id = cxc_clie.id
        WHERE fac_docs.serie_folio="""

    cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
    try:
        q = "{0}'{1}'".format(__EXTRA_INF_SQL, serie_folio)
        cur.execute(q)
        rows = cur.fetchall()
        if len(rows) > 0:
            return rows
        else:
            raise DocBuilderStepError('There is not extra info data')
    except psycopg2.Error as e:
        raise DocBuilderStepError("an error happen when loading extra info dat")


def __find_concept_in_cove(sku, cove_rows):
    """
    find an item over cove rows,
    this methods is not very smart
    due to it is using brute force
    """
    for item in cove_rows:
        if sku == "%s" % (item["sku"]):
            return True
    return False 


def __format_cove(cove_rows):

    rd = {}
    for i in cove_rows:
        rd["%s" % (i['sku'])] = {
            'cove_lts': "%s" % (i['cove_lts']),
            'cove_kgs': "%s" % (i['cove_kgs']),
            'mul_lit': "%s" % (i['mul_lit']),
            'mul_kgs': "%s" % (i['mul_kgs'])
        }
    return rd


def __format_extra_info(rows):

    rd = {}
    for i in rows:
        rd["PURCHASE_NUMBER"] = i['purchase_number'] if i['purchase_number'] else 'N/D'
        rd['CUSTOMER_CONTROL_ID'] = i['customer_control_id']
        rd['PAYMENT_CONSTRAINT'] = i['payment_constraint']
        rd['SALES_MAN'] = i['sales_man']
        rd['PAYMENT_DATE'] = i['payment_date']
        rd['CURRENCY_ABR'] = i['currency_abr']
        rd['CURRENCY_NAME'] = i['currency_name']
    return rd


def __apply_xslt(xml_filename, xsl_filename):

   dom = ET.parse(xml_filename)
   xslt = ET.parse(xsl_filename)
   transform = ET.XSLT(xslt)
   newdom = transform(dom)
   return str(newdom)


def __h_acquisition(logger, conn, res_dirs, **kwargs):
    """
    """
    dat = {
        'CUSTOMER_WWW':'www.exportacionessumar.com',
        'CUSTOMER_PHONE':'8112345678',
        'XML_PARSED': None,
        'STAMP_ORIGINAL_STR': None,
        'COVE_DATA': None,
        'EXTRA_INFO': None,
        'FOOTER_ABOUT': "ESTE DOCUMENTO ES UNA REPRESENTACIÓN IMPRESA DE UN CFDI"
    }

    cedula_filename = "{0}/{1}_cedula.png".format(
        res_dirs['images'],
        kwargs['rfc']
    )
    if not os.path.isfile(cedula_filename):
        raise DocBuilderStepError("{0} not found".format(cedula_filename))
    dat['CEDULA'] = cedula_filename

    logo_filename = "{0}/{1}_logo.png".format(
        res_dirs['images'],
        kwargs['rfc']
    )
    if not os.path.isfile(logo_filename):
        raise DocBuilderStepError("{0} not found".format(logo_filename))

    dat['LOGO'] = logo_filename
    cfdi_xml = "{0}/{1}/{2}".format(
        res_dirs['cfdi_output'],
        kwargs['rfc'] , kwargs['cfdi_xml']
    )
    if not os.path.isfile(cfdi_xml):
        raise DocBuilderStepError("cfdi xml not found")

    xslt_filename = "{0}/{1}/{2}".format(
        res_dirs['cfdi_xslt'], kwargs['rfc'],
        'cadena_original_timbre.xslt'
    )
    if not os.path.isfile(xslt_filename):
        raise DocBuilderStepError("cadena_original_timbre.xslt not found")
    
    parser = CfdiReader()
    try:
        dat['XML_PARSED'] = parser(cfdi_xml)
        dat['STAMP_ORIGINAL_STR'] = __apply_xslt(cfdi_xml, xslt_filename)
    except (xml.sax.SAXParseException) as e:
        logger.error(e)
        raise DocBuilderStepError("cfdi xml could not be parsed.")
    except (Exception) as e:
        logger.error(e)
        raise DocBuilderStepError("xsl could not be applied.")

    serie_folio = "%s%s" % (
        dat['XML_PARSED']['CFDI_SERIE'],
        dat['XML_PARSED']['CFDI_FOLIO']
    )

    try:
        cove_rows = __load_cove(conn, serie_folio)
        for artifact in dat['XML_PARSED']['ARTIFACTS']:
            if not __find_concept_in_cove(
               artifact['NOIDENTIFICACION'], cove_rows):
                raise Exception("concept not found in cove.")
        dat['COVE_DATA'] = __format_cove(cove_rows)
    except Exception as e:
        logger.error(e)
        raise DocBuilderStepError("cove verification fails")

    try:
        einfo_rows = __load_extra_info(conn, serie_folio)
        dat['EXTRA_INFO'] = __format_extra_info(einfo_rows)
    except Exception as e:
        logger.error(e)
        raise DocBuilderStepError("loading extra info fails")

    return dat


def __h_write_format(output_file, logger, dat):
    """
    """

    doc = BaseDocTemplate(
         output_file, pagesize=letter,
         rightMargin=30,leftMargin=30, topMargin=30,bottomMargin=18,
    )

    story = []

    logo = Image(dat['LOGO'])
    logo.drawHeight = 3.8*cm
    logo.drawWidth = 5.2*cm

    cedula = Image(dat['CEDULA'])
    cedula.drawHeight = 3.2*cm
    cedula.drawWidth = 3.2*cm

    story.append(
        __top_table(
            logo,
            __create_emisor_table(dat),
            __create_factura_table(dat)
        )
    )
    story.append(Spacer(1, 0.4 * cm))
    story.append(
        __customer_table(
            __create_customer_sec(dat),
            __create_extra_sec(dat)
        )
    )
    story.append(Spacer(1, 0.4 * cm))
    story.append(__create_arts_section(dat))
    story.append(
        __amount_table(
            __create_letra_section(dat),
            __create_total_section(dat)
        )
    )
    story.append(Spacer(1, 1.0 * cm))
    story.append(__info_cert_table(dat))
    story.append(
        __info_stamp_table(
            cedula,
            __create_seals_table(dat)
        )
    )
    story.append(__info_cert_extra(dat))

    def fp_foot(c, d):
        c.saveState()
        width, height = letter
        c.setFont('Helvetica',7)
        c.drawCentredString(width / 2.0, (1.00*cm), dat['FOOTER_ABOUT'])
        c.restoreState()

    bill_frame = Frame(
        doc.leftMargin, doc.bottomMargin, doc.width, doc.height,
        id='bill_frame'
    )

    doc.addPageTemplates(
        [
            PageTemplate(id='biil_page',frames=[bill_frame],onPage=fp_foot),
        ]
    )
    doc.build(story, canvasmaker=NumberedCanvas)

    return


def __chomp_extra_zeroes(a):

    if re.match("^\d+(\.\d{3})$", a):
        return  a[:-1]
    if re.match("^\d+(\.\d{4})$", a):
        return a[:-2]
    return a

def __info_cert_extra(dat):

    cont = []
    st = ParagraphStyle(name='info',fontName='Helvetica', fontSize=6.7, leading = 8)

    time_cert_info = {
        'label':"FECHA Y HORA DE CERTIFICACIÓN:",
        'scn': dat['XML_PARSED']['STAMP_DATE'],
    }

    no_cert_info = {
        'label':"NO. CERTIFICADO DEL SAT:",
        'scn': dat['XML_PARSED']['SAT_CERT_NUMBER'],
    }

    p_ti  = '''<para align=center><b>%(label)s</b> %(scn)s</para>''' % time_cert_info
    p_no  = '''<para align=center><b>%(label)s</b> %(scn)s</para>''' % no_cert_info

    cont.append([ Paragraph( p_no, st ), '', Paragraph( p_ti, st ) ])

    table = Table(cont,
        [
            8.0 * cm,
            1.0 * cm,
            9.0 * cm,
        ],
        [
            0.50*cm,
        ]
    )

    table.setStyle( TableStyle([
        ('BOX', (0, 0), (0, 0), 0.25, colors.black),

        ('VALIGN', (0, 0),(-1, -1), 'MIDDLE'),
        ('ALIGN', (0, 0),(-1, -1), 'CENTER'),

        ('BOX', (2, 0), (2, 0), 0.25, colors.black)
    ]))

    return table


def __info_cert_table(dat):

    cont = [['INFORMACIÓN DEL TIMBRE FISCAL DIGITAL']]
    st = ParagraphStyle(name='info',fontName='Helvetica', fontSize=6.5, leading = 8)

    table = Table(cont,
        [
            20.0 * cm
        ],
        [
            0.50*cm,
        ]
    )

    table.setStyle( TableStyle([
        ('BOX', (0, 0), (0, 0), 0.25, colors.black),
        ('VALIGN', (0, 0),(0, 0), 'MIDDLE'),
        ('ALIGN', (0, 0),(0, 0), 'LEFT'),
        ('FONT', (0, 0), (0, 0), 'Helvetica-Bold', 7),
        ('BACKGROUND', (0, 0),(0, 0), colors.black),
        ('TEXTCOLOR', (0, 0),(0, 0), colors.white)
    ]))

    return table


def __info_stamp_table(t0, t1):

    cont = [[t0, t1]]

    table = Table(cont,
        [
            4.0 * cm,
            16.0 * cm
        ],
        [
            4.0*cm
        ]
    )

    table.setStyle( TableStyle([
        ('BOX', (0, 0), (-1, -1), 0.25, colors.black),
        ('VALIGN', (0, 0),(-1, -1), 'MIDDLE'),
        ('ALIGN', (0, 0),(0, 0), 'CENTER'),

        ('ALIGN', (1, 0),(1, 0), 'LEFT'),
        ('BACKGROUND', (1, 0),(1, 0), colors.aliceblue),
        ('LINEBEFORE',(1,0),(1,0), 0.25, colors.black)
    ]))

    return table

def __create_seals_table(dat):

    cont = []
    st = ParagraphStyle(name='seal',fontName='Helvetica', fontSize=6.5, leading = 8)
    cont.append([ "CADENA ORIGINAL DEL TIMBRE:" ])
    cont.append([ Paragraph( dat['STAMP_ORIGINAL_STR'], st ) ])

    cont.append([ "SELLO DIGITAL DEL EMISOR:" ])
    cont.append([ Paragraph( dat['XML_PARSED']['CFD_SEAL'], st ) ])

    cont.append([ "SELLO DIGITAL DEL SAT:" ])
    cont.append([ Paragraph( dat['XML_PARSED']['SAT_SEAL'], st ) ])

    t = Table(
        cont,
        [
            15.5 * cm
        ],
        [
            0.4*cm,
            0.9*cm,
            0.4*cm,
            0.6*cm,
            0.4*cm,
            0.6*cm
        ]
    )

    t.setStyle( TableStyle([
        ('FONT', (0, 0), (0, 0), 'Helvetica-Bold', 6.5),
        ('FONT', (0, 2), (0, 2), 'Helvetica-Bold', 6.5),
        ('FONT', (0, 4), (0, 4), 'Helvetica-Bold', 6.5),
    ]))

    return t


def __top_table(t0, t1, t3):

    cont = [[t0, t1, t3]]

    table = Table(cont,
        [
            5.5 * cm,
            9.4 * cm,
            5.5 * cm
        ]
    )

    table.setStyle( TableStyle([
        ('ALIGN', (0, 0),(0, 0), 'LEFT'),
        ('ALIGN', (1, 0),(1, 0), 'CENTRE'),
        ('ALIGN', (-1, 0),(-1, 0), 'RIGHT'),
    ]))

    return table


def __create_emisor_table(dat):
    st = ParagraphStyle(
        name='info',
        fontName='Helvetica',
        fontSize=7,
        leading = 9.7 
    )

    context = {
        'inceptor': dat['XML_PARSED']['INCEPTOR_NAME'],
        'rfc': dat['XML_PARSED']['INCEPTOR_RFC'],
        'phone': dat['CUSTOMER_PHONE'],
        'www': dat['CUSTOMER_WWW'],
        'street': dat['XML_PARSED']['INCEPTOR_STREET'],
        'number': dat['XML_PARSED']['INCEPTOR_STREET_NUMBER'],
        'settlement': dat['XML_PARSED']['INCEPTOR_SETTLEMENT'],
        'state': dat['XML_PARSED']['INCEPTOR_STATE'].upper(),
        'town': dat['XML_PARSED']['INCEPTOR_TOWN'].upper(),
        'cp': dat['XML_PARSED']['INCEPTOR_CP'].upper(),
        'regimen': dat['XML_PARSED']['INCEPTOR_REGIMEN'].upper(),
        'op': dat['XML_PARSED']['CFDI_ORIGIN_PLACE'].upper(),
                     'fontSize': '7',
                     'fontName':'Helvetica',
    }

    text = Paragraph(
        '''
        <para align=center spaceb=3>
            <font name=%(fontName)s size=10 >
                <b>%(inceptor)s</b>
            </font>
            <br/>
            <font name=%(fontName)s size=%(fontSize)s >
                <b>RFC: %(rfc)s</b>
            </font>
            <br/>
            <font name=%(fontName)s size=%(fontSize)s >
                <b>DOMICILIO FISCAL</b>
            </font>
            <br/>
            %(street)s %(number)s %(settlement)s
            <br/>
            %(town)s, %(state)s C.P. %(cp)s
            <br/>
            TEL./FAX. %(phone)s
            <br/>
            %(www)s
            <br/>
            %(regimen)s
            <br/><br/>
            <b>LUGAR DE EXPEDICIÓN</b>
            <br/>
            %(op)s
        </para>
        ''' % context, st)

    cont = [[text]]

    table = Table(cont,
        colWidths = [ 9.0 *cm]
    )

    table.setStyle(TableStyle(
        [('VALIGN',(-1,-1),(-1,-1),'TOP')]
    ))

    return table


def __create_factura_table(dat):

    st = ParagraphStyle(
        name='info',
        fontName='Helvetica',
        fontSize=7,
        leading = 8
    )

    serie_folio = "%s%s" % (
        dat['XML_PARSED']['CFDI_SERIE'],
        dat['XML_PARSED']['CFDI_FOLIO']
    )

    cont = []

    cont.append(['FACTURA'])
    cont.append(['No.' ])
    cont.append([ serie_folio ])

    cont.append(['FECHA Y HORA'])
    cont.append([ dat['XML_PARSED']['CFDI_DATE'] ])

    cont.append(['FOLIO FISCAL'])
    cont.append([ Paragraph( dat['XML_PARSED']['UUID'], st ) ])

    cont.append(['NO. CERTIFICADO'])
    cont.append([ dat['XML_PARSED']['CFDI_CERT_NUMBER'] ])


    table = Table(cont,
        [
           5  * cm,
        ],
        [
            0.40 * cm,
            0.37* cm,
            0.37 * cm,
            0.38 * cm,
            0.38 * cm,
            0.38 * cm,
            0.70 * cm,
            0.38 * cm,
            0.38 * cm,
        ] # rowHeights
    )

    table.setStyle( TableStyle([

        #Body and header look and feel (common)
        ('BOX', (0, 1), (-1, -1), 0.25, colors.black),
        ('FONT', (0, 0), (0, 0), 'Helvetica-Bold', 10),

        ('TEXTCOLOR', (0, 1),(-1, 1), colors.white),
        ('FONT', (0, 1), (-1, 2), 'Helvetica-Bold', 7),

        ('TEXTCOLOR', (0, 3),(-1, 3), colors.white),
        ('FONT', (0, 3), (-1, 3), 'Helvetica-Bold', 7),
        ('FONT', (0, 4), (-1, 4), 'Helvetica', 7),

        ('TEXTCOLOR', (0, 5),(-1, 5), colors.white),
        ('FONT', (0, 5), (-1, 5), 'Helvetica-Bold', 7),

        ('FONT', (0, 7), (-1, 7), 'Helvetica-Bold', 7),
        ('TEXTCOLOR', (0, 7),(-1, 7), colors.white),
        ('FONT', (0, 8), (-1, 8), 'Helvetica', 7),

        ('ROWBACKGROUNDS', (0, 1),(-1, -1), [colors.black, colors.white]),
        ('ALIGN', (0, 0),(-1, -1), 'CENTER'),
        ('VALIGN', (0, 1),(-1, -1), 'MIDDLE'),
    ]))

    return table


def __customer_table(t0, t1):

    cont = [[t0,t1]]

    table = Table(cont,
        [
            8.4 * cm,
            12 * cm
        ]
    )

    table.setStyle( TableStyle([
        ('ALIGN', (0, 0),(0, 0), 'LEFT'),
        ('ALIGN', (-1, -1),(-1, -1), 'RIGHT'),
    ]))

    return table


def __create_customer_sec(dat):

    cont = []

    cont.append(['CLIENTE'])
    cont.append([ dat['XML_PARSED']['RECEPTOR_NAME'].upper() ])

    cont.append(['R.F.C.'])
    cont.append([ dat['XML_PARSED']['RECEPTOR_RFC'].upper() ])

    cont.append(['DIRECCIÓN'])
    cont.append([ (
        "{0} {1}".format(
            dat['XML_PARSED']['RECEPTOR_STREET'],
            dat['XML_PARSED']['RECEPTOR_STREET_NUMBER']
        )
    ).upper() ])
    cont.append([ dat['XML_PARSED']['RECEPTOR_SETTLEMENT'].upper() ])
    cont.append([ "{0}, {1}".format(
        dat['XML_PARSED']['RECEPTOR_TOWN'],
        dat['XML_PARSED']['RECEPTOR_STATE']
    ).upper()])
    cont.append([ dat['XML_PARSED']['RECEPTOR_COUNTRY'].upper() ])
    cont.append([ "%s %s" % ("C.P.", dat['XML_PARSED']['RECEPTOR_CP']) ])

    table = Table(cont,
        [
            8.3 * cm   # rowWitdhs
        ],
        [0.35*cm] * 10 # rowHeights
    )

    table.setStyle( TableStyle([

        #Body and header look and feel (common)
        ('ROWBACKGROUNDS', (0, 0),(-1, 4), [colors.aliceblue, colors.white]),
        ('ALIGN', (0, 1),(-1, -1), 'LEFT'),
        ('VALIGN', (0,0),(-1,-1), 'MIDDLE'),
        ('BOX', (0, 0), (-1, -1), 0.25, colors.black),
        ('TEXTCOLOR', (0,0),(-1,-1), colors.black),
        ('FONT', (0, 0), (-1, 0), 'Helvetica-Bold', 7),
        ('FONT', (0, 1), (-1, 1), 'Helvetica', 7),
        ('FONT', (0, 2), (-1, 2), 'Helvetica-Bold', 7),
        ('FONT', (0, 3), (-1, 3), 'Helvetica', 7),
        ('FONT', (0, 4), (-1, 4), 'Helvetica-Bold', 7),
        ('FONT', (0, 5), (-1, 9), 'Helvetica', 7),
    ]))

    return table

def __create_extra_sec(dat):

    cont = []

    cont.append(['NO. DE CLIENTE', 'METODO DE PAGO' ])
    cont.append([ dat['EXTRA_INFO']['CUSTOMER_CONTROL_ID'], dat['XML_PARSED']['METODO_PAGO'] ])

    cont.append(['NO. DE ORDEN', 'CONDICIONES DE PAGO'])
    cont.append([ dat['EXTRA_INFO']['PURCHASE_NUMBER'], dat['EXTRA_INFO']['PAYMENT_CONSTRAINT'] ])

    cont.append(['MONEDA', 'FORMA DE PAGO'])
    cont.append([ dat['EXTRA_INFO']['CURRENCY_ABR'], dat['XML_PARSED']['FORMA_PAGO'] ])

    cont.append(['TIPO DE CAMBIO', 'NO. DE CUENTA'])
    cont.append([ dat['XML_PARSED']['MONEY_EXCHANGE'], "0" ])

    cont.append(['FECHA DE PAGO', 'AGENTE DE VENTAS'])
    cont.append([ dat['EXTRA_INFO']['PAYMENT_DATE'], dat['EXTRA_INFO']['SALES_MAN']])

    table = Table(cont,
        [
            4.3 * cm,
            7.0 * cm   # rowWitdhs
        ],
        [0.35*cm] * 10 # rowHeights
    )

    table.setStyle( TableStyle([

        #Body and header look and feel (common)
        ('VALIGN', (0,0),(-1,-1), 'MIDDLE'),
        ('BOX', (0, 0), (-1, -1), 0.25, colors.black),
        ('TEXTCOLOR', (0,0),(-1,-1), colors.black),
        ('FONT', (0, 0), (-1, 0), 'Helvetica-Bold', 7),
        ('FONT', (0, 1), (-1, 1), 'Helvetica', 7),
        ('FONT', (0, 2), (-1, 2), 'Helvetica-Bold', 7),
        ('FONT', (0, 3), (-1, 3), 'Helvetica', 7),
        ('FONT', (0, 4), (-1, 4), 'Helvetica-Bold', 7),
        ('FONT', (0, 5), (-1, 5), 'Helvetica', 7),
        ('FONT', (0, 6), (-1, 6), 'Helvetica-Bold', 7),
        ('FONT', (0, 7), (-1, 7), 'Helvetica', 7),
        ('FONT', (0, 8), (-1, 8), 'Helvetica-Bold', 7),
        ('FONT', (0, 9), (-1, 9), 'Helvetica', 7),
        ('ROWBACKGROUNDS', (0, 0),(-1, -1), [colors.aliceblue, colors.white]),
        ('ALIGN', (0, 1),(-1, -1), 'LEFT'),
    ]))

    return table

def __create_arts_section(dat):

    st = ParagraphStyle(
        name='info',
        fontName='Helvetica',
        fontSize=7,
        leading = 8
    )

    header_concepts = (
        'CLAVE', 'DESCRIPCIÓN', 'UNIDAD', 'CANTIDAD',
        'COVE LTS', 'COVE KGS', 'P.UNITARIO', 'IMPORTE'
    )

    cont_concepts = []
    for i in dat['XML_PARSED']['ARTIFACTS']:
        covelts = dat['COVE_DATA'][i['NOIDENTIFICACION']]['mul_lit']
        covekgs = dat['COVE_DATA'][i['NOIDENTIFICACION']]['mul_kgs']
        row = [
                i['NOIDENTIFICACION'],
                Paragraph( i['DESCRIPCION'], st),
                i['UNIDAD'].upper(),
                currency_format(__chomp_extra_zeroes(i['CANTIDAD'])),
                currency_format(__chomp_extra_zeroes(covelts)),
                currency_format(__chomp_extra_zeroes(covekgs)),
                currency_format(__chomp_extra_zeroes(i['VALORUNITARIO'])),
                currency_format(__chomp_extra_zeroes(i['IMPORTE']))
        ]
        cont_concepts.append(row)

    cont = [header_concepts] + cont_concepts

    table = Table(cont,
        [
            1.9 * cm,
            5.2 * cm,
            2.0 * cm,
            2.0 * cm,
            2.1 * cm,
            2.0 * cm,
            2.3 * cm,
            2.5 * cm
        ]
    )

    table.setStyle( TableStyle([

        #Body and header look and feel (common)
        ('ALIGN', (0,0),(-1,0), 'CENTER'),
        ('VALIGN', (0,0),(-1,-1), 'TOP'),
        ('BOX', (0, 0), (-1, 0), 0.25, colors.black),
        ('BACKGROUND', (0,0),(-1,0), colors.black),
        ('TEXTCOLOR', (0,0),(-1,0), colors.white),
        ('FONT', (0, 0), (-1, -1), 'Helvetica', 7),
        ('FONT', (0, 0), (-1, 0), 'Helvetica-Bold', 7),
        ('ROWBACKGROUNDS', (0, 1),(-1, -1), [colors.white, colors.aliceblue]),
        ('ALIGN', (0, 1),(2, -1), 'LEFT'),
        ('ALIGN', (3, 1),(-1, -1), 'RIGHT'),

        #Clave column look and feel (specific)
        ('BOX', (0, 1), (0, -1), 0.25, colors.black),

        #Description column look and feel (specific)
        ('BOX', (1, 1), (1, -1), 0.25, colors.black),

        #Unit column look and feel (specific)
        ('BOX', (2, 1), (2, -1), 0.25, colors.black),

        #Amount column look and feel (specific)
        ('BOX', (3, 1),(3, -1), 0.25, colors.black),

        #Amount column look and feel (specific)
        ('BOX', (4, 1),(4, -1), 0.25, colors.black),

        #Amount column look and feel (specific)
        ('BOX', (5, 1),(5, -1), 0.25, colors.black),

        #Amount column look and feel (specific)
        ('BOX', (6, 1),(6, -1), 0.25, colors.black),

        #Amount column look and feel (specific)
        ('BOX', (7, 1),(7, -1), 0.25, colors.black),
    ]))

    return table

def __create_total_section(dat):

    cont = [
       ["SUB-TOTAL", dat['EXTRA_INFO']['CURRENCY_ABR'],
       currency_format(
           __chomp_extra_zeroes(dat['XML_PARSED']['CFDI_SUBTOTAL']))
       ]
    ]

    for imptras in dat['XML_PARSED']['TAXES']['TRAS']['DETAILS']:
        (tasa, _) = imptras['TASA'].split('.')

        row = [
            "{0} {1}%".format(imptras['IMPUESTO'], tasa),
            dat['EXTRA_INFO']['CURRENCY_ABR'],
            currency_format(__chomp_extra_zeroes(imptras['IMPORTE']))
        ]
        cont.append(row)

    cont.append([
        "TOTAL", dat['EXTRA_INFO']['CURRENCY_ABR'],
        currency_format(__chomp_extra_zeroes(dat['XML_PARSED']['CFDI_TOTAL']))
    ])

    table_total = Table(cont,
        [
            3.8 * cm,
            1.3 * cm,
            2.5 * cm  # rowWitdhs
        ],
        [0.4*cm] * len(cont) # rowHeights
    )

    table_total.setStyle( TableStyle([
        ('VALIGN', (0,0),(-1,-1), 'MIDDLE'),
        ('ALIGN',  (0,0),(-1,-1), 'RIGHT'),
        ('BOX', (0, 0), (-1, -1), 0.25, colors.black),

        ('FONT', (0, 0), (0, -1), 'Helvetica-Bold', 7),

        ('BOX', (1, 0), (2, -1), 0.25, colors.black),

        ('FONT', (1, 0), (1, 1), 'Helvetica', 7),
        ('FONT', (1, 2), (1, 2), 'Helvetica-Bold', 7),
        ('FONT', (-1, 0), (-1, -1), 'Helvetica-Bold', 7),
    ]))

    return table_total


def __create_letra_section(dat):

    cont = [ [''], ["IMPORTE CON LETRA"] ]

    (c,d) = dat['XML_PARSED']['CFDI_TOTAL'].split('.')
    n = transnum_spa(c)
    result = "{0} {1} {2}/100 {3}".format(
        n.upper(),
        dat['EXTRA_INFO']['CURRENCY_NAME'],
        d,
        dat['EXTRA_INFO']['CURRENCY_ABR']
    )

    # substitute multiple whitespace with single whitespace
    cont.append([ ' '.join(result.split()) ] )

    table_letra = Table(cont,
        [
            12.3 * cm  # rowWitdhs
        ],
        [0.4*cm] * len(cont) # rowHeights
    )

    table_letra.setStyle( TableStyle([
        ('VALIGN', (0,0),(-1,-1), 'MIDDLE'),
        ('ALIGN',  (0,0),(-1,-1), 'LEFT'),

        ('FONT', (0, 1), (-1, 1), 'Helvetica-Bold', 7),

        ('FONT', (0, 2), (-1, 2), 'Helvetica', 7),
    ]))

    return table_letra


def __amount_table(t0, t1):

    cont = [[t0,t1]]

    table = Table(cont,
        [
            12.4 * cm,
            8 * cm
        ],
        [1.31 * cm] * len(cont) # rowHeights
    )

    table.setStyle( TableStyle([
        ('ALIGN', (0, 0),(0, 0), 'LEFT'),
        ('ALIGN', (-1, -1),(-1, -1), 'RIGHT'),
    ]))

    return table

def __h_data_release(logger, dat):
    """
    """
    pass


doc_builder_impt = {
    'DATA_ACQUISITION': __h_acquisition,
    'WRITE_FORMAT': __h_write_format,
    'DATA_RELEASE': __h_data_release
}

