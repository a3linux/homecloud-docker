Boostack Tips
=========================

* Bookstack SSO/SAML with Authentik

There is a file _etc/dotenv_of_bookstack_ as reference.
The complete _.env_ sample is [here](https://github.com/BookStackApp/BookStack/blob/development/.env.example.complete).

* How to hide sidebar content for vistor? 

This is from the [Github issue](https://github.com/BookStackApp/BookStack/issues/1291)
```javascript
<script>
	window.addEventListener('DOMContentLoaded', (event) => {
		const loginShowing = document.querySelector('a[href$="/login"]') !== null;
		const leftPanel = document.querySelector("div.tri-layout-left");
		const rightPanel = document.querySelector("div.tri-layout-right");
        const leftActivity = document.querySelector("#recent-activity");
        if (loginShowing && leftActivity) {
            //leftActivity.style.visibility = 'hidden';
            leftActivity.innerHTML = "";
        }
		if (loginShowing && leftPanel) {
            leftPanel.style.display = 'none';
            leftPanel.innerHTML = "";
		}
        if (loginShowing && rightPanel) {
            rightPanel.style.display = 'none';
            rightPanel.innerHTML = "";
        }
	});
</script>
```
