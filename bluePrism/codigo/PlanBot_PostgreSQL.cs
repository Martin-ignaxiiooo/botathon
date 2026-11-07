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
