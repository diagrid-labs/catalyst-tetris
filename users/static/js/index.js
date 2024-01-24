function validateSignupForm() {
    var usernameInput = document.getElementById('username');
    var passwordInput = document.getElementById('password');
    var passwordInputConfirmation = document.getElementById('password-confirmation');
    var errorMessage = document.getElementById('error-message');
    var regex = /^[a-zA-Z0-9]+$/;

    if (!regex.test(usernameInput.value)) {
        errorMessage.textContent = 'Username must contain only letters and numbers.';
        return false;
    }

    if (usernameInput.value.length < 4 || passwordInput.value.length > 20) {
        errorMessage.textContent = 'Username must be between 4 and 20 characters.';
        return false;
    }

    if (passwordInput.value.length < 8 || passwordInput.value.length > 20) {
        errorMessage.textContent = 'Password must be between 8 and 20 characters.';
        return false;
    }

    if (passwordInput.value != passwordInputConfirmation.value) {
        errorMessage.textContent = 'Please make sure your passwords match.';
        return false;
    }

    errorMessage.textContent = ''; // Clear any previous error message
    return true;
}