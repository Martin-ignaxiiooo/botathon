// Programa de consola de verificación. NO pegar en Blue Prism.
using System;
using System.Data;
using System.Globalization;
using System.IO;
using Microsoft.VisualBasic.FileIO;

public class Probar_CodeStages
{
    private static void Exigir(bool condicion, string mensaje) { if (!condicion) throw new Exception(mensaje); }
    private static DataTable Csv(string ruta, bool cabecera)
    {
        DataTable t = new DataTable();
        using (TextFieldParser p = new TextFieldParser(ruta, System.Text.Encoding.UTF8))
        {
            p.TextFieldType = FieldType.Delimited; p.SetDelimiters(","); p.HasFieldsEnclosedInQuotes = true; p.TrimWhiteSpace = false;
            string[] primera = p.ReadFields();
            for (int i = 0; i < primera.Length; i++) t.Columns.Add(cabecera ? primera[i] : "c" + i, typeof(object));
            if (!cabecera) t.Rows.Add(primera);
            while (!p.EndOfData) t.Rows.Add(p.ReadFields());
        }
        return t;
    }
    public static void Main(string[] args)
    {
        if (args.Length != 3) throw new Exception("Uso: prueba.exe original.csv errores.csv esperado_errores.csv");
        CultureInfo.CurrentCulture = CultureInfo.GetCultureInfo("es-CL");
        PlanBot_Limpieza limpieza = new PlanBot_Limpieza();
        DataTable original, malas; decimal descartadas;
        limpieza.LimpiarDotacion(Csv(args[0], false), out original, out descartadas);
        limpieza.LimpiarDotacion(Csv(args[1], false), out malas, out descartadas);
        Exigir(descartadas > 0, "Debe descartar cabeceras/blancos");
        Exigir(malas.Columns.Count == 17 && !malas.Columns.Contains("Fecha de Nacimiento"), "Minimización/columnas");
        Exigir(Convert.ToInt32(malas.Rows[0]["fila"]) == 3, "Primera fila original debe ser 3");
        DataTable its = new DataTable(); its.Columns.Add("it");
        DataTable cargos = new DataTable(); cargos.Columns.Add("cargo_origen");
        foreach (DataRow r in original.Rows) { its.Rows.Add(r["it"]); cargos.Rows.Add(r["cargo"]); }
        PlanBot_Validador validador = new PlanBot_Validador();
        DataTable validas, errores;
        validador.ValidarDotacion(malas, its, cargos, 17m, out validas, out errores);
        int encontrados = 0;
        foreach (DataRow esperado in Csv(args[2], true).Rows)
        {
            bool hallado = false;
            foreach (DataRow e in errores.Rows)
                if (Convert.ToString(e["persona_id"], CultureInfo.InvariantCulture) == (string)esperado["persona_id"] && (string)e["campo"] == (string)esperado["campo"])
                { hallado = true; Console.WriteLine(e["persona_id"] + " / " + e["campo"] + " / " + e["motivo"]); }
            Exigir(hallado, "No se detectó: " + esperado["persona_id"] + " / " + esperado["campo"]);
            encontrados++;
        }
        Exigir(encontrados == 5, "Deben comprobarse cinco errores esperados");
        Exigir(validas.Columns.Count == 17 && !validas.Columns.Contains("fila"), "Contrato stg sin columna fila");
        Exigir(validas.Columns["horas_semanales"].DataType == typeof(decimal), "Número decimal tipado");
        DateTime fechaIso;
        Exigir(DateTime.TryParseExact((string)validas.Rows[0]["periodo"], "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out fechaIso), "Fecha ISO");
        // Varias fallas en una fila, coma decimal, límites, claves equivalentes y nulos.
        DataTable sinteticas = original.Clone();
        sinteticas.ImportRow(original.Rows[0]);
        sinteticas.Rows[0]["persona_id"] = "x"; sinteticas.Rows[0]["it"] = "999999";
        sinteticas.Rows[0]["periodo"] = "2026-02-30"; sinteticas.Rows[0]["horas_semanales"] = "46";
        validador.ValidarDotacion(sinteticas, its, cargos, 17m, out validas, out errores);
        Exigir(validas.Rows.Count == 0 && errores.Rows.Count >= 4 && errores.Rows[0].IsNull("persona_id"), "Errores múltiples y persona NULL");
        sinteticas.Rows.Clear(); sinteticas.ImportRow(original.Rows[0]);
        sinteticas.Rows[0]["horas_semanales"] = "40,5";
        sinteticas.Rows[0]["fecha_termino"] = DBNull.Value;
        validador.ValidarDotacion(sinteticas, its, cargos, 17m, out validas, out errores);
        Exigir(errores.Rows.Count == 0 && (decimal)validas.Rows[0]["horas_semanales"] == 40.5m && validas.Rows[0].IsNull("fecha_termino"), "Coma decimal y NULL");
        sinteticas.ImportRow(sinteticas.Rows[0]);
        sinteticas.Rows[1]["periodo"] = new DateTime(2026, 1, 1);
        validador.ValidarDotacion(sinteticas, its, cargos, 17m, out validas, out errores);
        Exigir(errores.Rows.Count == 1 && ((string)errores.Rows[0]["motivo"]).Contains("duplicada"), "Duplicado fecha texto/DateTime");
        DataTable rango = new DataTable(); for (int i = 0; i < 14; i++) rango.Columns.Add("c" + i, typeof(object));
        rango.Rows.Add("KI", "KINESIOLOGO", "atenciones", 30, 30, "65%", "15%", "20%", "0,5", "0,3", "0,2", DBNull.Value, DBNull.Value, DBNull.Value);
        DataTable reglas, alertas;
        new PlanBot_Reglas().TransformarDistribucion(rango, out reglas, out alertas);
        Exigir(reglas.Rows.Count == 3 && alertas.Rows.Count == 1 && (int)alertas.Rows[0]["tramo"] == 3, "Tramos, vacíos y alertas");
        Exigir((decimal)reglas.Rows[0]["pct_dir"] == 0.65m && (decimal)reglas.Rows[1]["pct_nas"] == 0.2m, "Porcentajes y coma");
        Console.WriteLine("OK: 5/5 errores esperados; limpieza, filas, conversión, duplicados, múltiples errores y reglas.");
    }
}
