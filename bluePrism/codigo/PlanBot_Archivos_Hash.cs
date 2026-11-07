// Archivo compilable. En el Code stage pegar SOLO el cuerpo de CalcularHash.
using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;

public class PlanBot_Archivos_Hash
{
    // ACCIÓN: Calcular Hash. Entrada ruta (Text), salida hash (Text).
    public void CalcularHash(string ruta, out string hash)
    {
        using (FileStream archivo = new FileStream(ruta, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
        using (SHA256 algoritmo = SHA256.Create())
        {
            byte[] bytes = algoritmo.ComputeHash(archivo);
            StringBuilder texto = new StringBuilder(bytes.Length * 2);
            foreach (byte valor in bytes) texto.Append(valor.ToString("x2"));
            hash = texto.ToString();
        }
    }
}
