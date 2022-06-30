function onDocReady(callback)
{
	if (document.readyState === "complete" || document.readyState === "interactive")
	{
		setTimeout(callback, 1);
	}
	else
	{
		document.addEventListener("DOMContentLoaded", callback);
	}
}

function hasProperty(object, key)
{
	return object ? hasOwnProperty.call(object, key) : false;
}

class Upgrade
{
	url = '/';
	verifying = 0;
	field = null;
	button = null;
	status = null;
	message = null;

	constructor(elements)
	{
		if (
			!hasProperty(elements, 'field') || typeof(elements['field']) == 'undefined' || elements['field'] == null ||
			!hasProperty(elements, 'button') || typeof(elements['button']) == 'undefined' || elements['button'] == null ||
			!hasProperty(elements, 'status') || typeof(elements['status']) == 'undefined' || elements['status'] == null ||
			!hasProperty(elements, 'message') || typeof(elements['message']) == 'undefined' || elements['message'] == null
		)
		{
			throw new Error('Malformed document. Please try reloading page.');
		}

		this.field = elements['field'];
		this.button = elements['button'];
		this.status = elements['status'];
		this.message = elements['message'];

		this.field.addEventListener('input', (event) =>
		{
			if (this.verifying)
			{
				return false;
			}

			if (this.fieldVerify())
			{
				this.button.disabled = false;
				this.button.classList.remove('disabled');

				return true;
			}

			this.button.disabled = true;
			this.button.classList.add('disabled');
		});

		this.button.addEventListener('click', (event) =>
		{
			this.submit();
		});

		this.field.addEventListener('keypress', (event) =>
		{
			let keyCode = (event.keyCode ? event.keyCode : event.which);

			if (keyCode == 13)
			{
				this.submit();
			}
		});

		this.field.focus();
	}

	formState(lock = true)
	{
		if (lock)
		{
			this.field.disabled = false;

			return true;
		}

		this.field.disabled = true;
		this.button.disabled = true;
		this.button.classList.add('disabled');
	}

	submit()
	{
		if (this.verifying == 1 || ! this.fieldVerify())
		{
			return false;
		}

		this.verifying = 1;
		let value = this.field.value;
		this.field.value = '';
		this.button.innerHTML = 'Verifying';
		this.formState(false);
		this.setStatus();

		return this.send(value)
			.then(result =>
			{
				let status = '';

				if (result !== null && typeof result === 'object' && hasProperty(result, 'status'))
				{
					status = result.status;
				}

				switch (String(status))
				{
					case '1':
					{
						this.setStatus('Upgrading...', 'success');
						this.button.innerHTML = 'Please wait';
						setTimeout(() =>
						{
							location.reload() 
						}, 30000);

						return true;
					}

					case '2':
					{
						this.setStatus('Incorrect key', 'error');
					
						break;
					}

					case '3':
					{
						this.setStatus('Verification timeout', 'error');
					
						break;
					}

					case '-1':
					{
						this.setStatus('Incorrect input', 'error');
					
						break;
					}
					default:
					{
						this.setStatus('Unknown response', 'error');
					}
				}

				this.button.innerHTML = 'Authorize';
				this.formState();
				this.field.focus();
				this.verifying = 0;

				return false;
			})
			.catch(error =>
			{
				console.log(error);
				this.setStatus('Unexpected error', 'error');
				this.button.innerHTML = 'Authorize';
				this.formState();
				this.field.focus();
				this.verifying = 0;

				return false;
			});
	}

	fieldVerify()
	{
		let fieldLength = this.field.value.length;

		if (fieldLength >= 8 && fieldLength <= 64)
		{
			return true
		}

		return false;
	}

	setStatus(message = '', type = null)
	{
		this.status.setAttribute('class', '');
		this.status.style.visibility = 'hidden';
		this.status.style.opacity = 0;

		while (this.status.firstChild)
		{
			this.status.removeChild(this.status.firstChild);
		}

		if (message == '')
		{
			return true;
		}

		this.status.appendChild(document.createTextNode(message));

		if (type != null)
		{
			this.status.setAttribute('class', `status_${type}`);
		}

		this.status.style.visibility = 'visible';
		this.status.style.opacity = 1;
	}

	async send(value)
	{
		const requestResult = await fetch(this.url,
			{
				method: 'POST',
				cache: 'no-cache',
				headers: new Headers({
					'Accept': 'application/json',
					'Content-Type': 'application/json; charset=UTF-8'
					// 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
				}),
				body: JSON.stringify({
					'psk': value
				})
			})
			.then(response =>
			{
				if (response.status != 200)
				{
					throw response.status;
				}

				return response.json();
			})
			.catch(error =>
			{
				console.log(error);

				return false;
			});

		return requestResult;
	}
}

onDocReady(function ()
{
	try
	{
		new Upgrade({
			'field': document.getElementById('upgrade_field'),
			'button': document.getElementById('upgrade_submit'),
			'status': document.getElementById('upgrade_status'),
			'message': document.getElementById('upgrade_message')
		});
	}
	catch (exception)
	{
		alert(exception);
	}
});