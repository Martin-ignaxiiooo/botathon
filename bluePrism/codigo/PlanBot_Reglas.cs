using System;
using System.Data;
using System.Globalization;

public class PlanBot_Reglas
{
    #region Global Code
    private decimal ValorRegla(object v)
    {
        string s = Convert.ToString(v, CultureInfo.InvariantCulture).Trim();
        if (s == "") return 0;
        bool porcentaje = s.EndsWith("%", StringComparison.Ordinal);
        if (porcentaje) s = s.Substring(0, s.Length - 1).Trim();
        decimal n;
        if ((s.Contains(",") && s.Contains(".")) || !Decimal.TryParse(s.Replace(',', '.'), NumberStyles.AllowLeadingSign | NumberStyles.AllowDecimalPoint, CultureInfo.InvariantCulture, out n))
            throw new Exception("Valor de distribución no numérico: " + s);
        return porcentaje ? n / 100 : n;
    }
    #endregion

    // ACCIÓN Transformar Distribucion: A7:N92 SIN consumir fila 7 como cabecera.
    public void TransformarDistribucion(DataTable rango, out DataTable param_cargo, out DataTable alertas)
    {
        if (rango == null || rango.Columns.Count < 14) throw new Exception("Se requieren las 14 columnas A:N del rango A7:N92.");
        param_cargo = new DataTable();
        foreach (string c in new string[] { "cod_esp", "cargo", "unidad" }) param_cargo.Columns.Add(c, typeof(string));
        foreach (string c in new string[] { "min_directa", "min_indirecta", "tramo" }) param_cargo.Columns.Add(c, typeof(int));
        foreach (string c in new string[] { "pct_dir", "pct_ind", "pct_nas" }) param_cargo.Columns.Add(c, typeof(decimal));
        alertas = new DataTable();
        alertas.Columns.Add("cargo", typeof(string)); alertas.Columns.Add("tramo", typeof(int));
        alertas.Columns.Add("suma", typeof(decimal)); alertas.Columns.Add("motivo", typeof(string));
        foreach (DataRow r in rango.Rows)
        {
            string cargo = Convert.ToString(r[1], CultureInfo.InvariantCulture).Trim();
            if (cargo == "") continue;
            decimal directa = ValorRegla(r[3]), indirecta = ValorRegla(r[4]);
            if (directa != Decimal.Truncate(directa) || indirecta != Decimal.Truncate(indirecta) || directa < 0 || indirecta < 0 || directa > Int32.MaxValue || indirecta > Int32.MaxValue)
                throw new Exception("Minutos deben ser enteros no negativos: " + cargo);
            for (int tramo = 1; tramo <= 3; tramo++)
            {
                int col = 5 + (tramo - 1) * 3;
                decimal dir = ValorRegla(r[col]), ind = ValorRegla(r[col + 1]), nas = ValorRegla(r[col + 2]);
                param_cargo.Rows.Add(Convert.ToString(r[0], CultureInfo.InvariantCulture).Trim(), cargo, Convert.ToString(r[2], CultureInfo.InvariantCulture).Trim(), (int)directa, (int)indirecta, tramo, dir, ind, nas);
                decimal suma = dir + ind + nas;
                if (Math.Abs(suma - 1) > 0.001m) alertas.Rows.Add(cargo, tramo, suma, "Distribución directa + indirecta + NAS no suma 1 ± 0.001");
            }
        }
    }
}
