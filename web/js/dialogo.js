// Diálogos accesibles de un solo campo: motivo de una decisión (aprobar o rechazar un escenario) y token del
// planificador. Usan <dialog> con showModal(): el resto de la página queda inerte, el foco queda dentro, Esc cierra
// y el foco vuelve al botón que lo abrió.
import { el, idUnico } from './ui.js';

export const MOTIVO_MINIMO = 5;

/**
 * Abre un diálogo con un campo y devuelve una promesa: true si se guardó, false si se canceló.
 * `validar(valor)` devuelve un mensaje de error (o null si está bien); `guardar(valor)` devuelve una promesa y,
 * si lanza un error, el diálogo sigue abierto y lo muestra con `prefijoError`.
 */
function abrirDialogoCampo({
  titulo, descripcion, etiqueta, tipo = 'textarea', placeholder = '', textoConfirmar, prefijoError, validar, guardar,
}) {
  const idTitulo = idUnico('dlg-titulo');
  const idDescripcion = idUnico('dlg-desc');
  const idCampo = idUnico('dlg-campo');
  const idError = idUnico('dlg-error');
  const origen = document.activeElement;

  const atributos = { id: idCampo, name: 'valor', required: true, 'aria-describedby': `${idError} ${idDescripcion}`, placeholder };
  const campo = tipo === 'textarea'
    ? el('textarea', { ...atributos, rows: '4' })
    : el('input', { ...atributos, type: tipo, autocomplete: 'off', spellcheck: 'false' });
  const error = el('p', { id: idError, class: 'error-campo', role: 'alert' });
  const confirmar = el('button', { type: 'submit', class: 'boton-primario' }, textoConfirmar);
  const cancelar = el('button', { type: 'button' }, 'Cancelar');
  const formulario = el('form', { method: 'dialog', novalidate: true },
    el('h2', { id: idTitulo }, titulo),
    el('p', { id: idDescripcion }, descripcion),
    el('div', { class: 'campo' }, el('label', { for: idCampo }, etiqueta), campo, error),
    el('div', { class: 'acciones-dialogo' }, cancelar, confirmar));
  const dialogo = el('dialog', { class: 'dialogo', 'aria-labelledby': idTitulo, 'aria-describedby': idDescripcion }, formulario);
  document.body.append(dialogo);

  return new Promise((resolver) => {
    let guardado = false;
    let terminado = false;
    // Limpieza única: se llama al cerrar con los botones y también cuando el navegador cierra con Esc.
    const finalizar = () => {
      if (terminado) return;
      terminado = true;
      dialogo.remove();
      if (origen?.isConnected) origen.focus(); // si la pantalla se redibujó, quien llamó decide dónde va el foco
      resolver(guardado);
    };
    const cerrar = () => { if (dialogo.open) dialogo.close(); finalizar(); };

    cancelar.addEventListener('click', cerrar);
    dialogo.addEventListener('close', finalizar);

    formulario.addEventListener('submit', async (e) => {
      e.preventDefault();
      const valor = campo.value.trim();
      const problema = validar(valor);
      if (problema) {
        error.textContent = problema;
        campo.setAttribute('aria-invalid', 'true');
        campo.focus();
        return;
      }
      error.textContent = '';
      campo.removeAttribute('aria-invalid');
      confirmar.disabled = true;
      cancelar.disabled = true;
      confirmar.textContent = 'Guardando…';
      try {
        await guardar(valor);
        guardado = true;
        cerrar();
      } catch (fallo) {
        error.textContent = `${prefijoError}: ${fallo.message}`;
        confirmar.disabled = false;
        cancelar.disabled = false;
        confirmar.textContent = textoConfirmar;
        campo.focus();
      }
    });

    dialogo.showModal();
    campo.focus();
  });
}

/** Pide el motivo de aprobar o rechazar. `guardar(motivo)` hace la llamada a la API. */
export function abrirDialogoDecision({ titulo, descripcion, textoConfirmar, guardar }) {
  return abrirDialogoCampo({
    titulo, descripcion, textoConfirmar, guardar,
    etiqueta: `Motivo (obligatorio, mínimo ${MOTIVO_MINIMO} caracteres)`,
    placeholder: 'Escriba el motivo de la decisión',
    prefijoError: 'No se pudo guardar la decisión',
    validar: (motivo) => (motivo.length < MOTIVO_MINIMO ? `Escriba un motivo de al menos ${MOTIVO_MINIMO} caracteres.` : null),
  });
}

/**
 * Pide el token JWT del planificador (campo oculto). `validar(token)` revisa el formato y `guardar(token)` lo
 * recuerda (solo en sessionStorage, lo decide quien llama).
 */
export function abrirDialogoToken({ validar, guardar }) {
  return abrirDialogoCampo({
    titulo: 'Ingresar como planificador',
    descripcion: 'Pegue el token JWT de planificador que le entregó el equipo de base de datos. Se guarda solo en esta pestaña del navegador y se envía únicamente al aprobar o rechazar un escenario; se borra al salir o al cerrar la pestaña.',
    etiqueta: 'Token del planificador',
    tipo: 'password',
    placeholder: 'Pegue aquí el token',
    textoConfirmar: 'Ingresar',
    prefijoError: 'No se pudo ingresar',
    validar,
    guardar,
  });
}
