# Start HTTP listener on port 8080
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://*:8080/")
$listener.Start()

Write-Output "Servidor iniciado en http://localhost:8080/"

# Function to generate HTML table with process information
function Get-ProcessTableHtml {
    $html = @"
<html>
<head>
    <title>Monitoreo de Procesos</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f4f4f4;
            color: #333;
            margin: 0;
            padding: 0;
        }
        h2 {
            text-align: center;
            margin: 20px 0;
        }
        form {
            width: 90%;
            margin: 0 auto;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }
        th, td {
            padding: 10px;
            text-align: left;
        }
        th {
            background-color: #f0f0f0;
        }
        table, th, td {
            border: 1px solid #ddd;
        }
        tr:nth-child(even) {
            background-color: #f9f9f9;
        }
        input[type='radio'] {
            margin: auto;
            display: block;
        }
        input[type='submit'] {
            display: block;
            margin: 20px auto;
            padding: 10px 20px;
            background-color: #007bff;
            color: white;
            border: none;
            border-radius: 5px;
            cursor: pointer;
        }
        input[type='submit']:hover {
            background-color: #0056b3;
        }
        a {
            text-decoration: none;
            color: #007bff;
        }
        a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <h2>Monitoreo de Procesos</h2>
    <form method="POST" action="/kill">
        <table>
            <tr>
                <th>Seleccionar</th>
                <th>ID</th>
                <th>Nombre</th>
                <th>Uso de CPU (%)</th>
                <th>Memoria (MB)</th>
            </tr>
"@

    # List processes with CPU and memory info
    Get-Process | ForEach-Object {
        $id = $_.Id
        $name = $_.ProcessName
        $cpu = "{0:N2}" -f ($_.CPU -as [double])
        $memory = "{0:N2}" -f ($_.WorkingSet / 1MB)
        
        # Add a row for each process with a radio button
        $html += "<tr><td><input type='radio' name='processId' value='$id'/></td><td>$id</td><td>$name</td><td>$cpu</td><td>$memory</td></tr>"
    }
    
    $html += @"
        </table>
        <input type="submit" value="Terminar Proceso"/>
    </form>
</body>
</html>
"@

    return $html
}

# Function to handle incoming HTTP requests
while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response
    $response.ContentType = "text/html"
    
    # Handle GET requests to display the process table
    if ($request.HttpMethod -eq "GET") {
        $html = Get-ProcessTableHtml
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
    }
    # Handle POST requests to terminate the selected process
    elseif ($request.HttpMethod -eq "POST" -and $request.Url.AbsolutePath -eq "/kill") {
        # Read the POST data and extract the process ID
        $reader = New-Object System.IO.StreamReader($request.InputStream)
        $data = $reader.ReadToEnd()
        $processId = $data -replace '.*processId=([0-9]+).*','$1'

        # Logging to verify process ID extraction
        Write-Output "Attempting to kill process ID: $processId"

        try {
            # Use taskkill for compatibility
            Start-Process "taskkill" -ArgumentList "/PID $processId /F" -NoNewWindow -Wait
            $message = @"
<html>
<head><title>Proceso Terminado</title></head>
<body>
    <h2>Proceso $processId terminado correctamente.</h2>
    <a href="/">Volver a la lista de procesos</a>
</body>
</html>
"@
        } catch {
            $message = @"
<html>
<head><title>Error</title></head>
<body>
    <h2>Error al terminar el proceso $processId. Asegúrate de que tienes los permisos necesarios.</h2>
    <a href="/">Volver a la lista de procesos</a>
</body>
</html>
"@
        }
        
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($message)
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
    }
    
    $response.OutputStream.Close()
}

# Stop the listener when the script ends
$listener.Stop()