// Puente de contingencia: compila los BO originales, sin copiar sus reglas.
using System;
using System.Data;
using System.Globalization;
using System.IO;
using System.Text;
using System.Xml;

class PrepararBuk
{
    static void Csv(DataTable tabla, string ruta, int desde, int cantidad)
    {
        using (StreamWriter w = new StreamWriter(ruta, false, new UTF8Encoding(false)))
        {
            for (int c = 0; c < tabla.Columns.Count; c++)
            {
                if (c > 0) w.Write(',');
                w.Write('"' + tabla.Columns[c].ColumnName.Replace("\"", "\"\"") + '"');
            }
            w.WriteLine();
            for (int i = desde; i < desde + cantidad; i++)
            {
                for (int c = 0; c < tabla.Columns.Count; c++)
                {
                    if (c > 0) w.Write(',');
                    object valor = tabla.Rows[i][c];
                    if (Convert.IsDBNull(valor)) { w.Write(@"\N"); continue; }
                    string texto = valor is DateTime ? ((DateTime)valor).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)
                        : Convert.ToString(valor, CultureInfo.InvariantCulture);
                    w.Write('"' + texto.Replace("\"", "\"\"") + '"');
                }
                w.WriteLine();
            }
        }
    }

    static void Lotes(DataTable tabla, string carpeta, string prefijo)
    {
        for (int i = 0; i < tabla.Rows.Count; i += 500)
            Csv(tabla, Path.Combine(carpeta, prefijo + "_" + (i / 500).ToString("D4") + ".csv"), i, Math.Min(500, tabla.Rows.Count - i));
    }

    static void Main(string[] args)
    {
        XmlDocument xml = new XmlDocument(); xml.XmlResolver = null; xml.Load(args[0]);
        DataTable datos = new DataTable();
        int columnas = Int32.Parse(xml.DocumentElement.GetAttribute("columnas"), CultureInfo.InvariantCulture);
        for (int i = 0; i < columnas; i++) datos.Columns.Add("C" + i, typeof(object));
        foreach (XmlNode fila in xml.SelectNodes("/buk/datos/fila"))
        {
            DataRow r = datos.NewRow(); int i = 0;
            foreach (XmlNode celda in fila.ChildNodes)
            {
                string tipo = celda.Attributes["tipo"].Value;
                r[i++] = tipo == "null" ? (object)DBNull.Value : tipo == "numero"
                    ? (object)Double.Parse(celda.InnerText, NumberStyles.Float, CultureInfo.InvariantCulture)
                    : tipo == "fecha" ? (object)DateTime.ParseExact(celda.InnerText, "yyyy-MM-dd", CultureInfo.InvariantCulture)
                    : celda.InnerText;
            }
            datos.Rows.Add(r);
        }
        DataTable institutos = new DataTable(); institutos.Columns.Add("it", typeof(int));
        foreach (XmlNode it in xml.SelectNodes("/buk/institutos/it")) institutos.Rows.Add(Int32.Parse(it.InnerText, CultureInfo.InvariantCulture));
        DataTable cargos = new DataTable(); cargos.Columns.Add("cargo_origen", typeof(string));
        foreach (XmlNode cargo in xml.SelectNodes("/buk/cargos/cargo")) cargos.Rows.Add(cargo.InnerText);
        DataTable limpias, validas, errores, carga; decimal descartadas, leidas, nvalidas, nerror, mensajes;
        new PlanBot_Limpieza().LimpiarDotacion(datos, out limpias, out descartadas);
        new PlanBot_Validador().ValidarDotacion(limpias, institutos, cargos, Decimal.Parse(args[1], CultureInfo.InvariantCulture), out validas, out errores);
        new PlanBot_PostgreSQL().PrepararCarga(validas, limpias, errores, out carga, out leidas, out nvalidas, out nerror, out mensajes);
        Directory.CreateDirectory(args[2]);
        Lotes(carga, args[2], "buk"); Lotes(errores, args[2], "errores");
        Csv(errores, Path.Combine(args[2], "errores_completos.csv"), 0, errores.Rows.Count);
        File.WriteAllText(Path.Combine(args[2], "conteos.csv"), "leidas,validas,con_error,mensajes,descartadas\r\n" +
            String.Join(",", new string[] { leidas.ToString(CultureInfo.InvariantCulture), nvalidas.ToString(CultureInfo.InvariantCulture),
                nerror.ToString(CultureInfo.InvariantCulture), mensajes.ToString(CultureInfo.InvariantCulture), descartadas.ToString(CultureInfo.InvariantCulture) }), new UTF8Encoding(false));
    }
}
