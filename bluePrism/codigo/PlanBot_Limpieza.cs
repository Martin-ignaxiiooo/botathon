using System;
using System.Data;
using System.Globalization;
using System.Text;

public class PlanBot_Limpieza
{
    #region Global Code
    private string ClaveCabecera(object valor)
    {
        string texto = Convert.ToString(valor, CultureInfo.InvariantCulture).Normalize(NormalizationForm.FormD);
        StringBuilder salida = new StringBuilder();
        foreach (char c in texto)
            if (Char.IsLetterOrDigit(c) && CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark)
                salida.Append(Char.ToLowerInvariant(c));
        return salida.ToString();
    }

    private bool EsCabecera(object[] valores)
    {
        bool it = false, persona = false, periodo = false;
        foreach (object v in valores)
        {
            string k = ClaveCabecera(v);
            it |= k == "it"; persona |= k == "personaid"; periodo |= k == "periodo";
        }
        return it && persona && periodo;
    }

    private string DestinoCabecera(object valor)
    {
        switch (ClaveCabecera(valor))
        {
            case "it": return "it";
            case "instituto": return "instituto";
            case "personaid": return "persona_id";
            case "area": case "rea": return "area";
            case "nombresubarea": case "nombresubrea": return "sub_area";
            case "centrodecosto": return "centro_costo";
            case "periodo": return "periodo";
            case "tipodecontrato": return "tipo_contrato";
            case "tipotrabajador": return "tipo_trabajador";
            case "fechaingresocompania": case "fechaingresocompaa": return "fecha_ingreso";
            case "fechatermino": case "fechatrmino": return "fecha_termino";
            case "horassemanales": return "horas_semanales";
            case "cargo": return "cargo";
            case "diasdelajornada": case "dasdelajornada": return "dias_jornada";
            case "ndias": return "ndias";
            case "codesp": return "cod_esp";
            default: return null;
        }
    }
    #endregion

    // ACCIÓN Limpiar Dotacion: pegar solo el cuerpo en el Code stage.
    public void LimpiarDotacion(DataTable datos, out DataTable limpias, out decimal filasDescartadas)
    {
        if (datos == null) throw new Exception("Falta la colección datos.");
        int encabezado = -1;
        object[] nombres = null;
        for (int i = 0; i < datos.Rows.Count; i++)
            if (EsCabecera(datos.Rows[i].ItemArray)) { encabezado = i; nombres = datos.Rows[i].ItemArray; break; }
        // También admite VBO con encabezados ya consumidos como nombres de columna.
        if (nombres == null)
        {
            nombres = new object[datos.Columns.Count];
            for (int i = 0; i < nombres.Length; i++) nombres[i] = datos.Columns[i].ColumnName;
            if (!EsCabecera(nombres)) throw new Exception("No se encontró encabezado IT / PersonaId / Periodo.");
        }
        string[] destinos = { "it", "instituto", "persona_id", "area", "sub_area", "centro_costo", "periodo", "tipo_contrato", "tipo_trabajador", "fecha_ingreso", "fecha_termino", "horas_semanales", "cargo", "dias_jornada", "ndias", "cod_esp" };
        int[] indices = new int[destinos.Length];
        limpias = new DataTable();
        for (int j = 0; j < destinos.Length; j++)
        {
            indices[j] = -1;
            for (int i = 0; i < nombres.Length; i++)
                if (DestinoCabecera(nombres[i]) == destinos[j])
                {
                    if (indices[j] >= 0) throw new Exception("Columna repetida en encabezado: " + destinos[j]);
                    indices[j] = i;
                }
            if (indices[j] < 0) throw new Exception("Falta columna requerida: " + destinos[j]);
            limpias.Columns.Add(destinos[j], typeof(object));
        }
        limpias.Columns.Add("fila", typeof(int));
        filasDescartadas = encabezado + 1;
        for (int i = encabezado + 1; i < datos.Rows.Count; i++)
        {
            DataRow origen = datos.Rows[i];
            bool vacia = true;
            foreach (object v in origen.ItemArray)
                if (!String.IsNullOrWhiteSpace(Convert.ToString(v, CultureInfo.InvariantCulture))) { vacia = false; break; }
            if (vacia || EsCabecera(origen.ItemArray)) { filasDescartadas++; continue; }
            DataRow nueva = limpias.NewRow();
            for (int j = 0; j < destinos.Length; j++) nueva[j] = origen[indices[j]];
            // La cabecera corresponde a fila 2, incluso si VBO incluye fila 1 vacía.
            nueva["fila"] = encabezado < 0 ? i + 3 : i - encabezado + 2;
            limpias.Rows.Add(nueva);
        }
    }
}
