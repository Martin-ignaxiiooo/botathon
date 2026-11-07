// Lector de .xlsx SIN Excel instalado (solo bibliotecas del framework). Objeto "PlanBot - Excel", acción Leer Excel.
// Reemplaza a MS Excel VBO (Create Instance / Open Workbook / Get Worksheet As Collection / Close) cuando la VM no tiene Excel.
// NO pegar la clase completa en Blue Prism:
//   * Global Code: SOLO el contenido de la región Global Code.
//   * Code stage: SOLO el cuerpo del método LeerExcel.
// Compila con: C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /target:library /r:System.IO.Compression.dll /r:System.Xml.dll PlanBot_LeerExcel.cs
//
// Object Studio > Initialise > Code Options:
//   Language: C#
//   References : System.dll, System.Data.dll, System.Xml.dll, System.IO.Compression.dll
//   Namespaces : System, System.Data, System.IO, System.IO.Compression, System.Xml, System.Globalization, System.Collections.Generic
//
// Entrega la hoja COMPLETA desde A1, una fila de la Collection por fila del Excel (las filas vacías se conservan, así la fila
// de la Collection i corresponde a la fila Excel i+1, que es lo que espera Limpiar Dotacion). Columnas c0, c1, c2...
// Valores: texto -> string; número y fecha -> double (una fecha de Excel es un serial numérico: Validar Dotacion lo convierte);
// booleano -> bool; celda vacía -> DBNull.
using System;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Xml;

public class PlanBot_LeerExcel
{
    #region Global Code
    private int IndiceColumna(string referencia)
    {
        int n = 0;
        foreach (char c in referencia)
        {
            if (c >= 'A' && c <= 'Z') n = n * 26 + (c - 'A' + 1);
            else if (c >= 'a' && c <= 'z') n = n * 26 + (c - 'a' + 1);
            else break;
        }
        return n - 1;
    }

    private string RutaHoja(ZipArchive zip, string hoja)
    {
        string rid = null;
        ZipArchiveEntry libro = zip.GetEntry("xl/workbook.xml");
        if (libro == null) throw new Exception("El archivo no es un .xlsx válido (falta xl/workbook.xml).");
        using (XmlReader x = XmlReader.Create(libro.Open()))
            while (x.Read())
                if (x.NodeType == XmlNodeType.Element && x.LocalName == "sheet" && x.GetAttribute("name") == hoja)
                { rid = x.GetAttribute("id", "http://schemas.openxmlformats.org/officeDocument/2006/relationships"); break; }
        if (rid == null) throw new Exception("No existe la hoja " + hoja + ".");
        ZipArchiveEntry rels = zip.GetEntry("xl/_rels/workbook.xml.rels");
        using (XmlReader x = XmlReader.Create(rels.Open()))
            while (x.Read())
                if (x.NodeType == XmlNodeType.Element && x.LocalName == "Relationship" && x.GetAttribute("Id") == rid)
                {
                    string destino = x.GetAttribute("Target");
                    return destino.StartsWith("/") ? destino.Substring(1) : "xl/" + destino;
                }
        throw new Exception("No se encontró la hoja " + hoja + " en las relaciones del libro.");
    }

    private List<string> CadenasCompartidas(ZipArchive zip)
    {
        List<string> lista = new List<string>();
        ZipArchiveEntry entrada = zip.GetEntry("xl/sharedStrings.xml");
        if (entrada == null) return lista;
        using (XmlReader x = XmlReader.Create(entrada.Open()))
            while (x.Read())
                if (x.NodeType == XmlNodeType.Element && x.LocalName == "si")
                {
                    // Una cadena puede venir en varios <t> (texto con formato); se ignoran los de fonética (<rPh>).
                    System.Text.StringBuilder texto = new System.Text.StringBuilder();
                    XmlReader si = x.ReadSubtree();
                    bool fonetica = false;
                    while (si.Read())
                    {
                        if (si.NodeType == XmlNodeType.Element && si.LocalName == "rPh") fonetica = true;
                        else if (si.NodeType == XmlNodeType.EndElement && si.LocalName == "rPh") fonetica = false;
                        else if (si.NodeType == XmlNodeType.Element && si.LocalName == "t" && !fonetica) texto.Append(si.ReadElementContentAsString());
                    }
                    lista.Add(texto.ToString());
                }
        return lista;
    }

    private void Poner(DataTable tabla, int columna, object valor, ref object[] fila)
    {
        while (tabla.Columns.Count <= columna) tabla.Columns.Add("c" + tabla.Columns.Count, typeof(object));
        if (fila.Length <= columna) Array.Resize(ref fila, columna + 1);
        fila[columna] = valor;
    }
    #endregion

    // ACCIÓN: Leer Excel.
    // Entradas: ruta Text (archivo .xlsx completo); hoja Text (p. ej. "Dotacion_2026").
    // Salidas : datos Collection (sin campos prefijados); filasLeidas Number (filas de la Collection, incluye vacías).
    public void LeerExcel(string ruta, string hoja, out DataTable datos, out decimal filasLeidas)
    {
        if (String.IsNullOrEmpty(ruta) || !File.Exists(ruta)) throw new Exception("No existe el archivo: " + ruta);
        datos = new DataTable();
        // FileShare.ReadWrite: se puede leer aunque otro proceso lo tenga abierto (el archivo ya debe estar completo).
        using (FileStream flujo = new FileStream(ruta, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
        using (ZipArchive zip = new ZipArchive(flujo, ZipArchiveMode.Read))
        {
            List<string> compartidas = CadenasCompartidas(zip);
            ZipArchiveEntry entrada = zip.GetEntry(RutaHoja(zip, hoja));
            if (entrada == null) throw new Exception("No se pudo abrir la hoja " + hoja + ".");
            List<object[]> filas = new List<object[]>();
            using (XmlReader x = XmlReader.Create(entrada.Open()))
            {
                int fila = 0;          // índice 0-based de la fila actual
                object[] actual = null;
                while (x.Read())
                {
                    if (x.NodeType == XmlNodeType.Element && x.LocalName == "row")
                    {
                        string r = x.GetAttribute("r");
                        int numero = r != null ? Int32.Parse(r, CultureInfo.InvariantCulture) - 1 : fila;
                        while (filas.Count < numero) filas.Add(new object[0]);   // filas vacías intermedias
                        actual = new object[0];
                        fila = numero + 1;
                        if (x.IsEmptyElement) filas.Add(actual);
                    }
                    else if (x.NodeType == XmlNodeType.EndElement && x.LocalName == "row") filas.Add(actual);
                    else if (x.NodeType == XmlNodeType.Element && x.LocalName == "c" && actual != null)
                    {
                        string tipo = x.GetAttribute("t");
                        int col = IndiceColumna(x.GetAttribute("r") ?? "A");
                        object valor = DBNull.Value;
                        if (!x.IsEmptyElement)
                        {
                            XmlReader celda = x.ReadSubtree();
                            string v = null, inline = null;
                            while (celda.Read())
                            {
                                if (celda.NodeType != XmlNodeType.Element) continue;
                                if (celda.LocalName == "v") v = celda.ReadElementContentAsString();
                                else if (celda.LocalName == "is") { inline = ""; XmlReader s = celda.ReadSubtree(); while (s.Read()) if (s.NodeType == XmlNodeType.Element && s.LocalName == "t") inline += s.ReadElementContentAsString(); }
                            }
                            if (tipo == "s" && v != null) valor = compartidas[Int32.Parse(v, CultureInfo.InvariantCulture)];
                            else if (tipo == "inlineStr" && inline != null) valor = inline;
                            else if (tipo == "str" && v != null) valor = v;
                            else if (tipo == "b" && v != null) valor = v == "1";
                            else if (tipo == "e") valor = DBNull.Value;
                            else if (v != null) valor = Double.Parse(v, NumberStyles.Float, CultureInfo.InvariantCulture);
                        }
                        Poner(datos, col, valor, ref actual);
                    }
                }
            }
            int ancho = datos.Columns.Count;
            foreach (object[] f in filas)
            {
                DataRow nueva = datos.NewRow();
                for (int i = 0; i < ancho; i++) nueva[i] = i < f.Length && f[i] != null ? f[i] : DBNull.Value;
                datos.Rows.Add(nueva);
            }
        }
        filasLeidas = datos.Rows.Count;
    }
}
