# Logitec_battery

Muestra en la bandeja del sistema de Windows el porcentaje de batería de un ratón y un teclado Logitech conectados por Bluetooth (probado con MX Vertical y MX Keys S). Cada dispositivo tiene su propio icono, con un símbolo de ratón o de teclado y el porcentaje debajo: en verde si es 20 % o más y en rojo si baja de 20 %. Se actualiza cada 5 minutos.

Hace falta porque Logi Options+ no muestra la batería de algunos ratones por Bluetooth. Esta herramienta la lee directamente del dispositivo por HID++ 2.0, sin instalar nada más.

## Instalación

Requisitos: Windows 10 u 11 y los dispositivos Logitech emparejados por Bluetooth. No hace falta instalar nada más.

1. Descarga o clona este repositorio.
2. Abre PowerShell en la carpeta del repositorio y ejecuta:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Install.ps1
   ```

   Esto arranca la aplicación y la configura para iniciarse con Windows.
3. Los iconos aparecen en la bandeja del sistema. En Windows 11 pueden quedar ocultos en la flecha `^`: arrástralos a la barra para tenerlos siempre a la vista.

Clic derecho sobre un icono: **Actualizar** (lee la batería ahora) o **Salir**.

Para desinstalar: `powershell -ExecutionPolicy Bypass -File .\Install.ps1 -Uninstall`.

## Notas

- Solo funciona con dispositivos conectados por Bluetooth, no con receptor Unifying o Bolt.
- Algunos ratones (como el MX Vertical) informan la batería por niveles (por ejemplo 100, 50, 20 %) y no con porcentaje exacto. El dato es real, pero salta entre valores.
- Si un dispositivo está apagado o dormido, el icono conserva el último valor leído.
