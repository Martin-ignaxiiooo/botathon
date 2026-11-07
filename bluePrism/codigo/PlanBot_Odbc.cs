// Archivo compilable de referencia para el objeto "PlanBot - PostgreSQL" de Blue Prism 7.5.1.
// NO pegar la clase completa en Blue Prism:
//   * Global Code: copiar SOLO el contenido de la región Global Code (sin #region).
//   * Code stage: copiar SOLO el cuerpo del método de cada acción (sin firma ni llaves exteriores).
// Compila con: C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /target:library PlanBot_Odbc.cs
//
// Object Studio > Initialise > Code Options:
//   Language: C#
//   References : System.dll, System.Data.dll, System.Xml.dll
//   Namespaces : System, System.Data, System.Data.Odbc, System.Security, System.Runtime.InteropServices
//
// La conexión se abre en Conectar y queda en el objeto (campo de Global Code) hasta Desconectar. Un proceso debe
// llamar Conectar una vez, usar Ejecutar/Consultar/Insertar Tabla y SIEMPRE Desconectar (también en la página Error).
// No hay connStr entre acciones: la clave no sale de Conectar.
using System;
using System.Data;
using System.Data.Odbc;
using System.Runtime.InteropServices;
using System.Security;
using System.Text;
using System.Text.RegularExpressions;

public class PlanBot_Odbc
{
    #region Global Code
    private OdbcConnection conexion;   // conexión viva del objeto

    private const string Driver = "PostgreSQL Unicode(x64)";

    // La credencial de Blue Prism (Get Login) entrega la clave como tipo Password. En un Code stage un Password llega
    // como SecureString; si alguien la mapeó como Text llega como string. Este método acepta ambas y no la guarda.
    private string TextoClave(object clave)
    {
        if (clave == null) return "";
        SecureString segura = clave as SecureString;
        if (segura == null) return Convert.ToString(clave);
        IntPtr puntero = IntPtr.Zero;
        try { puntero = Marshal.SecureStringToGlobalAllocUnicode(segura); return Marshal.PtrToStringUni(puntero); }
        finally { if (puntero != IntPtr.Zero) Marshal.ZeroFreeGlobalAllocUnicode(puntero); }
    }

    private OdbcConnection Conexion()
    {
        if (conexion == null || conexion.State != ConnectionState.Open)
            throw new Exception("No hay conexión abierta: ejecutar la acción Conectar primero.");
        return conexion;
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

    private void AgregarFecha(OdbcCommand comando, object valor)
    {
        // Una fecha SIEMPRE va como OdbcType.Date, también la ausente (DBNull): nunca como NVarChar.
        if (valor != null && !Convert.IsDBNull(valor) && !(valor is DateTime))
            throw new Exception("Una fecha debe ser DateTime o DBNull (no texto).");
        OdbcParameter parametro = comando.Parameters.Add("p" + comando.Parameters.Count, OdbcType.Date);
        parametro.Value = valor == null || Convert.IsDBNull(valor) ? DBNull.Value : (object)((DateTime)valor).Date;
    }

    private void AgregarParametro(OdbcCommand comando, object valor)
    {
        object convertido = ConvertirValor(valor);
        if (convertido is DateTime) { AgregarFecha(comando, convertido); return; }
        OdbcType tipo = OdbcType.NVarChar;
        if (convertido is bool) tipo = OdbcType.Bit;
        else if (convertido is byte[]) tipo = OdbcType.VarBinary;
        else if (convertido is decimal) tipo = OdbcType.Decimal;
        else if (convertido is double || convertido is float) tipo = OdbcType.Double;
        else if (convertido is long) tipo = OdbcType.BigInt;
        else if (convertido is int || convertido is short || convertido is byte) tipo = OdbcType.Int;
        OdbcParameter parametro = comando.Parameters.Add("p" + comando.Parameters.Count, tipo);
        if (convertido is decimal) { parametro.Precision = 29; parametro.Scale = (byte)((Decimal.GetBits((decimal)convertido)[3] >> 16) & 0xFF); }
        parametro.Value = convertido;
    }

    // parametros: columnas nombre (Text, descriptivo) y valor. Opcional: columna tipo con "date" para tipar como fecha
    // un valor DBNull (un NULL sin tipo se enlazaría como texto). Los DateTime siempre van como Date.
    // ODBC ignora el nombre: importa el ORDEN de las filas, igual que los signos ?.
    private void AgregarParametros(OdbcCommand comando, DataTable parametros)
    {
        if (parametros == null) return;
        if (!parametros.Columns.Contains("valor")) throw new Exception("Falta la columna valor en parametros.");
        bool hayTipo = parametros.Columns.Contains("tipo");
        foreach (DataRow fila in parametros.Rows)
        {
            if (hayTipo && !fila.IsNull("tipo") && Convert.ToString(fila["tipo"]).Trim().ToLowerInvariant() == "date") AgregarFecha(comando, fila["valor"]);
            else AgregarParametro(comando, fila["valor"]);
        }
    }

    private string Marcadores(int cantidad)
    {
        StringBuilder texto = new StringBuilder();
        for (int i = 0; i < cantidad; i++) { if (i > 0) texto.Append(", "); texto.Append("?"); }
        return texto.ToString();
    }

    private string ValidarTabla(string tabla)
    {
        if (String.IsNullOrEmpty(tabla) || !Regex.IsMatch(tabla, @"\Astg\.[A-Za-z_][A-Za-z0-9_]*\z"))
            throw new Exception("Solo se admiten tablas stg con identificadores simples.");
        return "stg.\"" + tabla.Substring(4) + "\"";
    }

    private bool EsFechaBuk(string tabla, string columna)
    {
        return tabla == "stg.buk_fila" && (columna == "periodo" || columna == "fecha_ingreso" || columna == "fecha_termino");
    }

    private void CerrarSilencio()
    {
        if (conexion == null) return;
        try { conexion.Close(); } catch { }
        try { conexion.Dispose(); } catch { }
        conexion = null;
    }
    #endregion

    // ACCIÓN: Conectar.
    // Entradas: usuario Text; clave Password (de Credentials > Get Login, credencial PlanBot_Postgres);
    //           servidor Text (vacío = localhost); puerto Text (vacío = 5432); baseDatos Text (vacío = planbot).
    // Salidas : conectado Flag.
    // En el Code stage declarar clave con tipo de dato Password. No escribir ni registrar la clave ni la cadena de conexión.
    public void Conectar(string usuario, SecureString clave, string servidor, string puerto, string baseDatos, out bool conectado)
    {
        conectado = false;
        CerrarSilencio();   // una conexión anterior olvidada se cierra
        if (String.IsNullOrEmpty(usuario)) throw new Exception("Falta el usuario (credencial PlanBot_Postgres).");
        OdbcConnectionStringBuilder constructor = new OdbcConnectionStringBuilder();
        constructor["Driver"] = "{" + Driver + "}";
        constructor["Server"] = String.IsNullOrEmpty(servidor) ? "localhost" : servidor;
        constructor["Port"] = String.IsNullOrEmpty(puerto) ? "5432" : puerto;
        constructor["Database"] = String.IsNullOrEmpty(baseDatos) ? "planbot" : baseDatos;
        constructor["Uid"] = usuario;
        constructor["Pwd"] = TextoClave(clave);   // el builder escapa ; y llaves; la cadena no sale de este método
        OdbcConnection nueva = new OdbcConnection(constructor.ConnectionString);
        try { nueva.Open(); }
        catch (OdbcException ex)
        {
            nueva.Dispose();
            // Se informa solo el mensaje del driver/servidor (no incluye la clave) y nunca la cadena de conexión.
            throw new Exception("No se pudo conectar a PostgreSQL: " + ex.Message);
        }
        conexion = nueva;
        conectado = true;
    }

    // ACCIÓN: Ejecutar. INSERT/UPDATE/DELETE o una sentencia que no devuelve filas (autocommit).
    // Entradas: sql Text (con ?); parametros Collection (nombre Text, valor, tipo Text opcional).
    // Salidas : filasAfectadas Number.
    public void Ejecutar(string sql, DataTable parametros, out decimal filasAfectadas)
    {
        using (OdbcCommand comando = new OdbcCommand(sql, Conexion()))
        {
            AgregarParametros(comando, parametros);
            filasAfectadas = comando.ExecuteNonQuery();
        }
    }

    // ACCIÓN: Consultar. SELECT (incluye SELECT api.funcion(...)); devuelve las filas como Collection sin esquema fijo.
    // Entradas: sql Text (con ?); parametros Collection (nombre Text, valor, tipo Text opcional).
    // Salidas : resultado Collection; filasResultado Number.
    public void Consultar(string sql, DataTable parametros, out DataTable resultado, out decimal filasResultado)
    {
        using (OdbcCommand comando = new OdbcCommand(sql, Conexion()))
        {
            AgregarParametros(comando, parametros);
            resultado = new DataTable();
            using (OdbcDataAdapter adaptador = new OdbcDataAdapter(comando)) adaptador.Fill(resultado);
            filasResultado = resultado.Rows.Count;
        }
    }

    // ACCIÓN: Insertar Tabla (carga masiva por la conexión abierta; reemplaza a Carga Masiva de PlanBot_PostgreSQL).
    // Entradas: tabla Text ("stg.buk_fila" o "stg.error_fila"); datos Collection (columnas = columnas SQL exactas);
    //           tamanoLote Number (0 = 500).
    // Salidas : filasInsertadas Number. Cada lote se confirma por separado.
    // Las columnas periodo/fecha_ingreso/fecha_termino de stg.buk_fila deben ser DateTime (o DBNull): usar Preparar Carga.
    public void InsertarTabla(string tabla, DataTable datos, decimal tamanoLote, out decimal filasInsertadas)
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
            if (EsFechaBuk(tabla, columna.ColumnName) && columna.DataType != typeof(DateTime))
                throw new Exception("Columna " + columna.ColumnName + " debe ser DateTime; usar Preparar Carga antes.");
            if (columnas.Length > 0) columnas.Append(", ");
            columnas.Append("\"").Append(columna.ColumnName).Append("\"");
        }
        string insercion = "INSERT INTO " + destino + " (" + columnas + ") VALUES (" + Marcadores(datos.Columns.Count) + ")";
        filasInsertadas = 0;
        OdbcConnection con = Conexion();
        int inicio = 0;
        while (inicio < datos.Rows.Count)
        {
            int cantidad = Math.Min(lote, datos.Rows.Count - inicio);
            using (OdbcTransaction transaccion = con.BeginTransaction())
            using (OdbcCommand comando = new OdbcCommand(insercion, con, transaccion))
            {
                for (int i = inicio; i < inicio + cantidad; i++)
                {
                    comando.Parameters.Clear();
                    foreach (DataColumn columna in datos.Columns)
                    {
                        if (EsFechaBuk(tabla, columna.ColumnName)) AgregarFecha(comando, datos.Rows[i][columna]);
                        else AgregarParametro(comando, datos.Rows[i][columna]);
                    }
                    comando.ExecuteNonQuery();
                }
                transaccion.Commit();
                filasInsertadas += cantidad;
            }
            inicio += cantidad;
        }
    }

    // ACCIÓN: Desconectar. No falla si no había conexión (sirve en la página Error).
    // Entradas: ninguna. Salidas: desconectado Flag.
    public void Desconectar(out bool desconectado)
    {
        CerrarSilencio();
        desconectado = true;
    }
}
