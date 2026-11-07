// Archivo compilable de referencia. NO pegar la clase completa en Blue Prism.
// Global Code: copiar SOLO el contenido de la región Global Code.
// Code stage: copiar SOLO el cuerpo del método de la acción (sin su firma).
using System;
using System.Data;
using System.Data.Odbc;
using System.Text;
using System.Text.RegularExpressions;

public class PlanBot_PostgreSQL
{
    #region Global Code
    private OdbcConnection AbrirConexion(string connStr)
    {
        OdbcConnection conexion = new OdbcConnection(connStr);
        try { conexion.Open(); return conexion; }
        catch { conexion.Dispose(); throw; }
    }

    private object ConvertirValor(object valor)
    {
        if (valor == null || Convert.IsDBNull(valor)) return DBNull.Value;
        if (valor is char) return valor.ToString();
        if (valor is DateTime) return (DateTime)valor;
        if (valor is bool || valor is byte[] || valor is string ||
            valor is decimal || valor is double || valor is float ||
            valor is long || valor is int || valor is short || valor is byte)
            return valor;
        throw new Exception("Tipo de parámetro no admitido: " + valor.GetType().FullName);
    }

    private void AgregarParametro(OdbcCommand comando, object valor)
    {
        object convertido = ConvertirValor(valor);
        OdbcType tipo = OdbcType.NVarChar;
        if (convertido is bool) tipo = OdbcType.Bit;
        else if (convertido is DateTime) tipo = OdbcType.DateTime;
        else if (convertido is byte[]) tipo = OdbcType.VarBinary;
        else if (convertido is decimal) tipo = OdbcType.Decimal;
        else if (convertido is double || convertido is float) tipo = OdbcType.Double;
        else if (convertido is long) tipo = OdbcType.BigInt;
        else if (convertido is int || convertido is short || convertido is byte) tipo = OdbcType.Int;
        OdbcParameter parametro = comando.Parameters.Add("p" + comando.Parameters.Count, tipo);
        if (convertido is decimal) { parametro.Precision = 29; parametro.Scale = (byte)((Decimal.GetBits((decimal)convertido)[3] >> 16) & 0xFF); }
        parametro.Value = convertido;
    }

    private void AgregarParametros(OdbcCommand comando, DataTable parametros)
    {
        if (parametros == null) return;
        if (!parametros.Columns.Contains("valor")) throw new Exception("Falta la columna valor.");
        // ODBC ignora nombre: importa el orden de las filas, igual que los signos ?.
        foreach (DataRow fila in parametros.Rows) AgregarParametro(comando, fila["valor"]);
    }

    private string ValidarFuncion(string funcion)
    {
        if (String.IsNullOrEmpty(funcion) || !Regex.IsMatch(funcion, @"\A[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)?\z"))
            throw new Exception("Nombre de función inválido.");
        return funcion;
    }

    private string ValidarTabla(string tabla)
    {
        if (String.IsNullOrEmpty(tabla) || !Regex.IsMatch(tabla, @"\Astg\.[A-Za-z_][A-Za-z0-9_]*\z"))
            throw new Exception("Solo se admiten tablas stg con identificadores simples.");
        return "stg.\"" + tabla.Substring(4) + "\"";
    }

    private string Marcadores(int cantidad)
    {
        StringBuilder texto = new StringBuilder();
        for (int i = 0; i < cantidad; i++) { if (i > 0) texto.Append(", "); texto.Append("?"); }
        return texto.ToString();
    }
    #endregion

    // ACCIÓN auxiliar: Crear Parametros. T1/T2: Text; N1/N2/N4: Number.
    public void CrearParametros(string modo, string texto1, string texto2, decimal numero1,
        decimal numero2, decimal numero3, decimal numero4, out DataTable parametros)
    {
        if (modo != "T1" && modo != "T2" && modo != "N1" && modo != "N2" && modo != "N4")
            throw new Exception("Modo de parámetros no admitido: " + modo);
        bool texto = modo[0] == 'T';
        int cantidad = Int32.Parse(modo.Substring(1), System.Globalization.CultureInfo.InvariantCulture);
        parametros = new DataTable();
        parametros.Columns.Add("nombre", typeof(string));
        parametros.Columns.Add("valor", texto ? typeof(string) : typeof(decimal));
        object[] valores = texto ? new object[] { texto1, texto2 } : new object[] { numero1, numero2, numero3, numero4 };
        for (int i = 0; i < cantidad; i++) parametros.Rows.Add("p" + (i + 1), valores[i] ?? DBNull.Value);
    }

    // ACCIÓN auxiliar: Leer Numero Resultado. NULL no se convierte en un mes cero.
    public void LeerNumeroResultado(DataTable resultado, string columna, out decimal numero,
        out bool esNulo, out decimal filasResultado)
    {
        if (resultado == null) throw new Exception("Falta resultado.");
        filasResultado = resultado.Rows.Count;
        numero = 0; esNulo = true;
        if (resultado.Rows.Count == 0) return;
        if (resultado.Rows.Count != 1 || !resultado.Columns.Contains(columna))
            throw new Exception("Se esperaba una fila y columna " + columna);
        if (resultado.Rows[0].IsNull(columna)) return;
        numero = Convert.ToDecimal(resultado.Rows[0][columna], System.Globalization.CultureInfo.InvariantCulture);
        esNulo = false;
    }

    // ACCIÓN auxiliar: Preparar Carga. No cuenta mensajes como filas rechazadas.
    public void PrepararCarga(DataTable validas, DataTable limpias, DataTable errores,
        out DataTable datosCarga, out decimal leidas, out decimal filasValidas,
        out decimal filasConError, out decimal mensajesError)
    {
        if (validas == null || limpias == null || errores == null || !errores.Columns.Contains("fila"))
            throw new Exception("Faltan colecciones de carga o columna fila.");
        datosCarga = validas.Clone();
        string[] fechas = { "periodo", "fecha_ingreso", "fecha_termino" };
        foreach (string campo in fechas) datosCarga.Columns[campo].DataType = typeof(DateTime);
        foreach (DataRow origen in validas.Rows)
        {
            DataRow destino = datosCarga.NewRow();
            foreach (DataColumn columna in validas.Columns)
            {
                object valor = origen[columna];
                if (Array.IndexOf(fechas, columna.ColumnName) >= 0 && !Convert.IsDBNull(valor))
                    valor = valor is DateTime ? valor : DateTime.ParseExact((string)valor, "yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture);
                destino[columna.ColumnName] = valor;
            }
            datosCarga.Rows.Add(destino);
        }
        // Dictionary está en mscorlib; no exige System.Core fuera de Code Options.
        System.Collections.Generic.Dictionary<int, bool> filas = new System.Collections.Generic.Dictionary<int, bool>();
        foreach (DataRow error in errores.Rows) filas[Convert.ToInt32(error["fila"], System.Globalization.CultureInfo.InvariantCulture)] = true;
        leidas = limpias.Rows.Count; filasValidas = validas.Rows.Count;
        filasConError = filas.Count; mensajesError = errores.Rows.Count;
        if (filasValidas + filasConError != leidas) throw new Exception("Los conteos de filas no cuadran.");
    }

    // ACCIÓN: Ejecutar Consulta. Copiar el cuerpo entre llaves.
    public void EjecutarConsulta(string connStr, string sql, DataTable parametros, out DataTable resultado)
    {
        using (OdbcConnection conexion = AbrirConexion(connStr))
        using (OdbcCommand comando = new OdbcCommand(sql, conexion))
        {
            AgregarParametros(comando, parametros);
            resultado = new DataTable();
            using (OdbcDataAdapter adaptador = new OdbcDataAdapter(comando)) adaptador.Fill(resultado);
        }
    }

    // ACCIÓN: Ejecutar Comando.
    public void EjecutarComando(string connStr, string sql, DataTable parametros, out decimal filasAfectadas)
    {
        using (OdbcConnection conexion = AbrirConexion(connStr))
        using (OdbcCommand comando = new OdbcCommand(sql, conexion))
        {
            AgregarParametros(comando, parametros);
            filasAfectadas = comando.ExecuteNonQuery();
        }
    }

    // ACCIÓN: Ejecutar Función.
    public void EjecutarFuncion(string connStr, string funcion, DataTable argumentos, out DataTable resultado)
    {
        string consulta = "SELECT * FROM " + ValidarFuncion(funcion) + "(" + Marcadores(argumentos == null ? 0 : argumentos.Rows.Count) + ")";
        using (OdbcConnection conexion = AbrirConexion(connStr))
        using (OdbcCommand comando = new OdbcCommand(consulta, conexion))
        {
            AgregarParametros(comando, argumentos);
            resultado = new DataTable();
            using (OdbcDataAdapter adaptador = new OdbcDataAdapter(comando)) adaptador.Fill(resultado);
        }
    }

    // ACCIÓN: Carga Masiva. En BP inicializar tamanoLote en 500 (0 también usa 500).
    public void CargaMasiva(string connStr, string tabla, DataTable datos, decimal tamanoLote, out decimal filasInsertadas)
    {
        string destino = ValidarTabla(tabla);
        if (datos == null || datos.Columns.Count == 0) throw new Exception("datos debe tener columnas.");
        if (tamanoLote == 0) tamanoLote = 500;
        if (tamanoLote < 1 || tamanoLote > Int32.MaxValue || Decimal.Truncate(tamanoLote) != tamanoLote)
            throw new Exception("tamanoLote debe ser un entero positivo.");
        int lote = (int)tamanoLote;
        StringBuilder columnas = new StringBuilder();
        foreach (DataColumn columna in datos.Columns)
        {
            if (!Regex.IsMatch(columna.ColumnName, @"\A[A-Za-z_][A-Za-z0-9_]*\z")) throw new Exception("Columna inválida: " + columna.ColumnName);
            if (columnas.Length > 0) columnas.Append(", ");
            columnas.Append("\"").Append(columna.ColumnName).Append("\"");
        }
        string insercion = "INSERT INTO " + destino + " (" + columnas + ") VALUES (" + Marcadores(datos.Columns.Count) + ")";
        filasInsertadas = 0;
        using (OdbcConnection conexion = AbrirConexion(connStr))
        {
            int inicio = 0;
            while (inicio < datos.Rows.Count)
            {
                int cantidad = Math.Min(lote, datos.Rows.Count - inicio);
                using (OdbcTransaction transaccion = conexion.BeginTransaction())
                using (OdbcCommand comando = new OdbcCommand(insercion, conexion, transaccion))
                {
                    // Dispose revierte el lote abierto si falla. Los lotes anteriores ya están confirmados.
                    for (int i = inicio; i < inicio + cantidad; i++)
                    {
                        comando.Parameters.Clear();
                        foreach (DataColumn columna in datos.Columns) AgregarParametro(comando, datos.Rows[i][columna]);
                        comando.ExecuteNonQuery();
                    }
                    transaccion.Commit();
                    filasInsertadas += cantidad;
                }
                inicio += cantidad;
            }
        }
    }
}
