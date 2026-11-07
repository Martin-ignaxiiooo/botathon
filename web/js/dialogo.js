// Diálogo accesible para pedir un motivo antes de una decisión (aprobar o rechazar un escenario).
// Usa <dialog> con showModal(): el resto de la página queda inerte, el foco queda dentro, Esc cierra y el
// foco vuelve al botón que lo abrió.
import { el, idUnico } from './ui.js';

export const MOTIVO_MINIMO = 5;

/**
 * Abre el diálogo y devuelve una promesa: true si la decisión se guardó, false si se canceló.
 * `guardar(motivo)` debe devolver una promesa; si lanza un error el diálogo sigue abierto y lo muestra.
 */
export function abrirDialogoDecision({ titulo, descripcion, textoConfirmar, guardar }) {
  const idTitulo = idUnico('dlg-titulo');
  const idDescripcion = idUnico('dlg-desc');
  const idMotivo = idUnico('dlg-motivo');
  const idError = idUnico('dlg-error');
  const origen = document.activeElement;

  const area = el('textarea', {
    id: idMotivo, name: 'motivo', rows: '4', required: true, 'aria-describedby': `${idError} ${idDescripcion}`,
    placeholder: 'Escriba el motivo de la decisión',
  });
  const error = el('p', { id: idError, class: 'error-campo', role: 'alert' });
  const confirmar = el('button', { type: 'submit', class: 'boton-primario' }, textoConfirmar);
  const cancelar = el('button', { type: 'button' }, 'Cancelar');
  const formulario = el('form', { method: 'dialog', novalidate: true },
    el('h2', { id: idTitulo }, titulo),
    el('p', { id: idDescripcion }, descripcion),
    el('div', { class: 'campo' },
      el('label', { for: idMotivo }, `Motivo (obligatorio, mínimo ${MOTIVO_MINIMO} caracteres)`), area, error),
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
      const motivo = area.value.trim();
      if (motivo.length < MOTIVO_MINIMO) {
        error.textContent = `Escriba un motivo de al menos ${MOTIVO_MINIMO} caracteres.`;
        area.setAttribute('aria-invalid', 'true');
        area.focus();
        return;
      }
      error.textContent = '';
      area.removeAttribute('aria-invalid');
      confirmar.disabled = true;
      cancelar.disabled = true;
      confirmar.textContent = 'Guardando…';
      try {
        await guardar(motivo);
        guardado = true;
        cerrar();
      } catch (fallo) {
        error.textContent = `No se pudo guardar la decisión: ${fallo.message}`;
        confirmar.disabled = false;
        cancelar.disabled = false;
        confirmar.textContent = textoConfirmar;
        area.focus();
      }
    });

    dialogo.showModal();
    area.focus();
  });
}
