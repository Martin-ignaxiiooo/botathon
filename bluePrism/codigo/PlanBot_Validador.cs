using System;
using System.Data;
using System.Globalization;
using System.Collections.Generic;

public class PlanBot_Validador
{
    #region Global Code
    private string Texto(object v) { return Convert.ToString(v, CultureInfo.InvariantCulture).Trim(); }

    private bool Numero(object v, out decimal numero)
    {
        string s = Texto(v);
        // Sin separadores de miles: evita interpretar 40,5 como 405.
        if (s.Contains(",") && s.Contains(".")) { numero = 0; return false; }
        return Decimal.TryParse(s.Replace(',', '.'), NumberStyles.AllowLeadingSign | NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out numero);
    }

    private bool Entero(object v, out long numero)
    {
        decimal d;
        numero = 0;
        if (!Numero(v, out d) || d != Decimal.Truncate(d) || d < Int64.MinValue || d > Int64.MaxValue) return false;
        numero = (long)d;
        return true;
    }

    private bool Fecha(object v, out DateTime fecha)
    {
        if (v is DateTime) { fecha = ((DateTime)v).Date; return true; }
        if (v is double || v is decimal || v is int || v is long)
        {
            try { fecha = DateTime.FromOADate(Convert.ToDouble(v, CultureInfo.InvariantCulture)).Date; return true; }
            catch (ArgumentException) { fecha = DateTime.MinValue; return false; }
        }
        return DateTime.TryParseExact(Texto(v), new string[] { "yyyy-MM-dd", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-ddTHH:mm:ss", "d/M/yyyy", "dd/MM/yyyy", "d-M-yyyy", "dd-MM-yyyy" }, CultureInfo.InvariantCulture, DateTimeStyles.None, out fecha);
    }

    private void ErrorFila(DataTable errores, long carga, DataRow fila, object persona, string campo, string motivo)
    {
        errores.Rows.Add(carga, fila["fila"], persona, campo, Texto(fila[campo]), motivo);
    }
    #endregion

    // ACCIÓN Validar Dotacion: pegar solo el cuerpo.
    public void ValidarDotacion(DataTable limpias, DataTable institutos, DataTable cargos, decimal cargaId, out DataTable validas, out DataTable errores)
    {
        if (limpias == null || institutos == null || cargos == null) throw new Exception("Faltan colecciones de validación.");
        if (cargaId < 1 || cargaId != Decimal.Truncate(cargaId) || cargaId > Int64.MaxValue) throw new Exception("cargaId debe ser un bigint positivo.");
        long carga = (long)cargaId;
        string[] campos = { "it", "instituto", "persona_id", "area", "sub_area", "centro_costo", "periodo", "tipo_contrato", "tipo_trabajador", "fecha_ingreso", "fecha_termino", "horas_semanales", "cargo", "dias_jornada", "ndias", "cod_esp" };
        foreach (string campo in campos) if (!limpias.Columns.Contains(campo)) throw new Exception("Falta columna " + campo);
        if (!limpias.Columns.Contains("fila") || !institutos.Columns.Contains("it") || !cargos.Columns.Contains("cargo_origen")) throw new Exception("Faltan fila o columnas de catálogo.");
        HashSet<long> its = new HashSet<long>();
        foreach (DataRow r in institutos.Rows) { long it; if (!Entero(r["it"], out it)) throw new Exception("IT inválido en catálogo."); its.Add(it); }
        HashSet<string> catalogo = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (DataRow r in cargos.Rows) if (Texto(r["cargo_origen"]) != "") catalogo.Add(Texto(r["cargo_origen"]));
        if (its.Count == 0 || catalogo.Count == 0) throw new Exception("Catálogos vacíos: no se validará sin referencias.");
        validas = new DataTable();
        validas.Columns.Add("carga_id", typeof(long));
        foreach (string campo in campos)
            validas.Columns.Add(campo, campo == "persona_id" ? typeof(long) : campo == "it" || campo == "ndias" ? typeof(int) : campo == "horas_semanales" ? typeof(decimal) : typeof(string));
        errores = new DataTable();
        errores.Columns.Add("carga_id", typeof(long)); errores.Columns.Add("fila", typeof(int)); errores.Columns.Add("persona_id", typeof(long));
        errores.Columns.Add("campo", typeof(string)); errores.Columns.Add("valor", typeof(string)); errores.Columns.Add("motivo", typeof(string));
        HashSet<string> vistos = new HashSet<string>(StringComparer.Ordinal);
        foreach (DataRow r in limpias.Rows)
        {
            int antes = errores.Rows.Count;
            long persona, it, ndias;
            decimal horas;
            DateTime periodo, ingreso, termino;
            bool pidOk = Entero(r["persona_id"], out persona);
            object pid = pidOk ? (object)persona : DBNull.Value;
            bool itOk = Entero(r["it"], out it) && it >= Int32.MinValue && it <= Int32.MaxValue;
            bool periodoOk = Fecha(r["periodo"], out periodo);
            bool ingresoOk = Fecha(r["fecha_ingreso"], out ingreso);
            bool tieneTermino = Texto(r["fecha_termino"]) != "";
            bool terminoOk = Fecha(r["fecha_termino"], out termino);
            bool horasOk = Numero(r["horas_semanales"], out horas);
            bool ndiasVacio = Texto(r["ndias"]) == "";
            bool ndiasOk = Entero(r["ndias"], out ndias) && ndias >= Int32.MinValue && ndias <= Int32.MaxValue;
            if (!pidOk) ErrorFila(errores, carga, r, pid, "persona_id", "PersonaId debe ser un número entero bigint");
            if (!periodoOk) ErrorFila(errores, carga, r, pid, "periodo", "Periodo debe ser una fecha válida");
            if (!ingresoOk) ErrorFila(errores, carga, r, pid, "fecha_ingreso", "Fecha Ingreso debe ser una fecha válida");
            if (!horasOk) ErrorFila(errores, carga, r, pid, "horas_semanales", "Horas Semanales debe ser numérico: " + Texto(r["horas_semanales"]));
            else if (horas < 1 || horas > 45) ErrorFila(errores, carga, r, pid, "horas_semanales", "Horas Semanales = " + Texto(r["horas_semanales"]) + ": debe estar entre 1 y 45");
            if (tieneTermino && !terminoOk) ErrorFila(errores, carga, r, pid, "fecha_termino", "Fecha Término debe ser una fecha válida");
            else if (tieneTermino && ingresoOk && termino <= ingreso) ErrorFila(errores, carga, r, pid, "fecha_termino", "Fecha Término debe ser posterior a Fecha Ingreso");
            if (!itOk || !its.Contains(it)) ErrorFila(errores, carga, r, pid, "it", "IT no existe en el catálogo de institutos");
            if (!catalogo.Contains(Texto(r["cargo"]))) ErrorFila(errores, carga, r, pid, "cargo", "Cargo sin homologar: " + Texto(r["cargo"]));
            if (!ndiasVacio && !ndiasOk) ErrorFila(errores, carga, r, pid, "ndias", "Ndias debe ser un número entero int");
            if (pidOk && itOk && periodoOk)
            {
                string clave = persona.ToString(CultureInfo.InvariantCulture) + "|" + it.ToString(CultureInfo.InvariantCulture) + "|" + periodo.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
                if (!vistos.Add(clave)) ErrorFila(errores, carga, r, pid, "persona_id", "Fila duplicada (persona_id, it, periodo)");
            }
            if (errores.Rows.Count != antes) continue;
            DataRow v = validas.NewRow();
            v["carga_id"] = carga;
            foreach (string campo in campos) if (validas.Columns[campo].DataType == typeof(string)) v[campo] = Texto(r[campo]);
            v["persona_id"] = persona; v["it"] = (int)it; v["horas_semanales"] = horas;
            v["ndias"] = ndiasVacio ? (object)DBNull.Value : (int)ndias;
            v["periodo"] = periodo.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
            v["fecha_ingreso"] = ingreso.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
            v["fecha_termino"] = tieneTermino ? (object)termino.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) : DBNull.Value;
            validas.Rows.Add(v);
        }
    }
}
