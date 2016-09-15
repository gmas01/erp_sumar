package com.agnux.cfd.v2;

import java.io.DataInputStream;
import java.io.File;
import java.security.*;
import javax.security.cert.X509Certificate;
import java.io.IOException;
import java.io.InputStream;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import org.apache.commons.ssl.PKCS8Key;

public class CryptoEngine {

   /**
     * Digitally Sign a String inserted.
     *
     * @param filename The file with a Path where private key is found.
     * @param password The password of The Prtivate key.
     * @param cadenaoriginal The String to be Signed.
     *
     * @return A character array with the Base64 encoded data.
     */
    public static String sign(String filename, String password, String cadenaoriginal) {

        String valor_retorno = null;
        byte[] clavePrivada = null;
        Signature firma = null;
        PKCS8Key pkcs8 = null;
        PrivateKey pk = null;

        try {
            clavePrivada = serializeFile(filename);
        } catch (Exception e) {
            System.out.println(e.toString());
        }

        try {
            pkcs8 = new PKCS8Key(clavePrivada, password.toCharArray());
            pk = pkcs8.getPrivateKey();
            firma = Signature.getInstance("SHA1withRSA", "SunRsaSign");
            firma.initSign(pk);
        } catch (GeneralSecurityException e) {
            e.printStackTrace();
        }

        try {
            firma.update(cadenaoriginal.getBytes("UTF-8"));
            byte[] firmaDigital = firma.sign();
            valor_retorno = new String(Base64Coder.encode(firmaDigital));
        } catch (Exception e) {
            e.printStackTrace();
        }

        return valor_retorno;
    }

    public static String encodeCertToBase64(String certifle){
        char[] psB64Certificate = null;
        FileInputStream fis;
        try {
            fis = new FileInputStream(certifle); // Se maneja la excepcion
            X509Certificate cert = X509Certificate.getInstance(fis);
            byte[] buf = cert.getEncoded();
            psB64Certificate = Base64Coder.encode(buf);
        } catch (Exception ex) {
            ex.printStackTrace();
        }


        return new String(psB64Certificate);
    }

    private static byte[] serializeFile(final String absPathToFile) throws FileNotFoundException, IOException {
        File f = new File(absPathToFile);
        FileInputStream fis = new FileInputStream(f);
        DataInputStream dis = new DataInputStream(fis);
        byte[] buffer = new byte[(int) f.length()];
        dis.readFully(buffer);
        dis.close();
        return buffer;
    }
}
