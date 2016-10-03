import logging
import sys
import os
import configparser
import psycopg2
from docmaker.error import DocBuilderImptError, DocBuilderStepError, DocBuilderError

sys.path.append(
    os.path.abspath(
        os.path.join(os.path.dirname(__file__), "builders")
    )
)

def __load_builder(m, config, logger):

    def is_module_supported():
        supported_ones = config['doc builders']['supported'].split(' ')

        if not m in supported_ones:
            self.__logger.fatal(
                "the requested doc builder({0}) is not supported".format(m)
            )
            raise DocBuilderImptError("unable to select a doc builder")

    builder = None
    is_module_supported()

    try:
        logger.debug("attempting the import of {0} library".format(m))
        impt_mod = __import__(m)

        if not hasattr(impt_mod, "doc_builder_impt"):
            msg = "module {0} has no doc_builder_impt attribute".format(m)
            raise DocBuilderImptError(msg)
        else:
            builder = getattr(impt_mod, "doc_builder_impt")
    except (ImportError) as e:
        logger.fatal("{0} support library failure".format(m))
        raise DocBuilderImptError(
            "library {0} could not be imported".format(m)
        )

    return builder

def __open_dbms_conn(settings, logger):
    try:
        pgsql_config = settings['pgsql conn']
        conn_str = "dbname={0} user={1} host={2} password={3} port={4}".format(
            pgsql_config['db'],
            pgsql_config['user'],
            pgsql_config['host'],
            pgsql_config['passwd'],
            pgsql_config['port']
        )

        return psycopg2.connect(conn_str)
    except psycopg2.Error as e:
        logger.error(e)
        raise DocBuilderError("dbms was not connected")
    except KeyError as e:
        logger.error(e)
        raise DocBuilderError("slack pgsql configuration")


def __run_pipeline(builder, settings, logger, output_file, **kwargs):

    dat = None
    doc = None
    res_dirs = None

    try:
        res_dirs = settings['resource dirs']
    except KeyError as e:
        logger.error(e)
        raise DocBuilderError(
            "slack resource dirs configuration"
        )

    conn = __open_dbms_conn(settings, logger)
    try:
        dat = builder['DATA_ACQUISITION'](logger, conn, res_dirs, **kwargs)
    except KeyError as e:
        logger.error(e)
        raise DocBuilderError(
            "There is not data acquisition function implemented"
        )
    except DocBuilderStepError:
        raise
    finally:
        conn.close()

    try:
        builder['WRITE_FORMAT'](output_file, logger, dat)
    except (KeyError) as e:
        logger.error(e)
        raise DocBuilderError(
            "There is not a function implemented to write the format"
        )
    except DocBuilderStepError:
        raise

    try:
        builder['DATA_RELEASE'](logger, dat)
    except (KeyError) as e:
        logger.error(e)
        raise DocBuilderError(
            "There is not data release function implemented"
        )
    except DocBuilderStepError:
        raise


def build_document(module, logger, settings, output_file, **kwargs):
    """"""
    builder = __load_builder(module, settings, logger)
    return __run_pipeline(builder, settings, logger, output_file, **kwargs)
