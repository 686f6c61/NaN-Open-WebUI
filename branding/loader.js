// Marca de la comunidad NaN en la pantalla de entrada.
//
// Open WebUI carga /static/loader.js en todas las paginas y lo trae vacio; la imagen lo
// sustituye por este fichero, asi que la personalizacion sobrevive a las
// actualizaciones de Open WebUI. Solo AÑADE elementos: la licencia de Open WebUI no
// permite quitar ni tapar su marca (nombre, logo, favicon) en instalaciones de mas de
// 50 usuarios.
(() => {
	const BADGE_LINK = 'https://nan.builders/?ref=built-with-nan';
	// Normas de NaN: enlazar la insignia desde nan.builders y no modificarla.
	const BADGE_LIGHT = 'https://nan.builders/badge/built-with-nan-light.svg';
	const BADGE_DARK = 'https://nan.builders/badge/built-with-nan-dark.svg';

	const isDark = () => document.documentElement.classList.contains('dark');

	const badge = () => {
		const a = document.createElement('a');
		a.id = 'nan-badge';
		a.href = BADGE_LINK;
		a.target = '_blank';
		a.rel = 'noopener';
		const img = document.createElement('img');
		img.alt = 'Built with NaN';
		img.width = 220;
		img.src = isDark() ? BADGE_DARK : BADGE_LIGHT;
		a.appendChild(img);
		return a;
	};

	const footer = () => {
		const div = document.createElement('div');
		div.id = 'nan-community';
		const logo = document.createElement('img');
		logo.alt = '';
		logo.src = isDark() ? '/static/branding/helmcode-symbol-white.svg' : '/static/branding/helmcode-symbol-color.svg';
		const text = document.createElement('span');
		text.textContent = 'NaN es la comunidad de inferencia de Helmcode';
		div.append(logo, text);
		return div;
	};

	const apply = () => {
		const card = document.getElementById('auth-login-card');
		if (!card) return;
		const form = card.querySelector('form');
		if (!form) return;
		if (!document.getElementById('nan-badge')) card.insertBefore(badge(), form);
		if (!document.getElementById('nan-community')) form.after(footer());
		// Si cambia el tema, actualiza las variantes clara/oscura.
		const dark = isDark();
		const img = document.querySelector('#nan-badge img');
		if (img) img.src = dark ? BADGE_DARK : BADGE_LIGHT;
		const logo = document.querySelector('#nan-community img');
		if (logo) logo.src = dark ? '/static/branding/helmcode-symbol-white.svg' : '/static/branding/helmcode-symbol-color.svg';
	};

	// Open WebUI es una aplicacion de una sola pagina: la entrada aparece y desaparece
	// sin recargar, asi que se vigila el DOM y el cambio de tema.
	const start = () => {
		apply();
		new MutationObserver(apply).observe(document.body, { childList: true, subtree: true });
		new MutationObserver(apply).observe(document.documentElement, { attributes: true, attributeFilter: ['class'] });
	};

	if (document.body) start();
	else document.addEventListener('DOMContentLoaded', start);
})();

// Sesion huerfana: si el navegador conserva la sesion de un usuario que ya no existe
// (por ejemplo, tras reinstalar y borrar la base de datos), /api/config responde 401 y
// Open WebUI se queda en /error. Se cierra esa sesion en el servidor (la cookie es
// httpOnly) y se vuelve a la entrada. Solo con 401: si el servidor no responde, no hace
// nada, asi que no puede entrar en bucle.
(async () => {
	try {
		const res = await fetch('/api/config', { credentials: 'include' });
		if (res.status !== 401) return;
		await fetch('/api/v1/auths/signout', { method: 'POST', credentials: 'include' });
		try {
			localStorage.removeItem('token');
		} catch (e) {}
		location.replace('/auth');
	} catch (e) {}
})();
