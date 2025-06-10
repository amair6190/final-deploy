document.addEventListener('DOMContentLoaded', function() {
    const form = document.getElementById('registrationForm');
    if (!form) return; // Exit if form not found

    const usernameInput = form.elements['username']; // More robust way to get form elements
    const passwordInput = form.elements['password1'];
    const confirmPasswordInput = form.elements['password2'];
    const registerButton = document.getElementById('registerButton');
    const buttonText = registerButton ? registerButton.querySelector('.button-text') : null;
    const buttonLoader = registerButton ? registerButton.querySelector('.button-loader') : null;

    // --- Password Toggle ---
    document.querySelectorAll('.toggle-password').forEach(toggle => {
        toggle.addEventListener('click', function() {
            const targetId = this.dataset.target;
            const passwordField = document.getElementById(targetId);
            if (passwordField) {
                if (passwordField.type === 'password') {
                    passwordField.type = 'text';
                    this.classList.remove('fa-eye-slash');
                    this.classList.add('fa-eye');
                } else {
                    passwordField.type = 'password';
                    this.classList.remove('fa-eye');
                    this.classList.add('fa-eye-slash');
                }
            }
        });
    });

    // --- Password Strength Meter ---
    const passwordStrengthDiv = document.getElementById('passwordStrength');
    const strengthBar = passwordStrengthDiv ? passwordStrengthDiv.querySelector('.strength-bar') : null;
    const strengthText = passwordStrengthDiv ? passwordStrengthDiv.querySelector('.strength-text') : null;

    if (passwordInput && strengthBar && strengthText) {
        passwordInput.addEventListener('input', function() {
            const password = this.value;
            let score = 0;
            let feedbackText = 'Weak';

            if (password.length === 0) {
                score = -1; // Special case for empty
                feedbackText = '';
            } else {
                if (password.length >= 8) score++;
                if (/[A-Z]/.test(password)) score++;
                if (/[a-z]/.test(password)) score++;
                if (/[0-9]/.test(password)) score++;
                if (/[^A-Za-z0-9\s]/.test(password)) score++; // Non-alphanumeric, not whitespace
            }
            
            let barWidthPercentage = 0;
            strengthBar.classList.remove('weak', 'medium', 'strong');

            if (score === -1) { // Empty
                 barWidthPercentage = 0;
            } else if (score <= 1) { // Weak
                barWidthPercentage = 25;
                strengthBar.classList.add('weak'); // Uses CSS for color
                feedbackText = 'Weak';
            } else if (score <= 3) { // Medium
                barWidthPercentage = 60;
                strengthBar.classList.add('medium');
                feedbackText = 'Medium';
            } else { // Strong (score 4 or 5)
                barWidthPercentage = 100;
                strengthBar.classList.add('strong');
                feedbackText = 'Strong';
            }
            
            strengthBar.style.width = barWidthPercentage + '%';
            strengthText.textContent = feedbackText;
        });
    }

    // --- Real-time Validation (Simple Example - can be expanded) ---
    function setFieldValidationState(inputElement, errorElement, isValid, errorMessage = '') {
        if (!inputElement || !errorElement) return;
        if (isValid) {
            inputElement.classList.remove('input-error');
            inputElement.classList.add('input-success');
            errorElement.textContent = '';
        } else {
            inputElement.classList.remove('input-success');
            inputElement.classList.add('input-error');
            errorElement.textContent = errorMessage;
        }
    }

    if (usernameInput) {
        const usernameErrorEl = document.getElementById('usernameError');
        usernameInput.addEventListener('blur', function() {
            const isValid = this.value.length >= 3;
            setFieldValidationState(this, usernameErrorEl, isValid, isValid ? '' : 'Username must be at least 3 characters.');
        });
    }
    
    if (confirmPasswordInput && passwordInput) {
        const confirmErrorEl = document.getElementById('confirmPasswordError');
        function validateConfirmPassword() {
            if (confirmPasswordInput.value.length === 0 && passwordInput.value.length === 0) {
                 setFieldValidationState(confirmPasswordInput, confirmErrorEl, true); // Both empty is fine
                 return;
            }
            const isValid = confirmPasswordInput.value === passwordInput.value;
            setFieldValidationState(confirmPasswordInput, confirmErrorEl, isValid, isValid ? '' : 'Passwords do not match.');
        }
        confirmPasswordInput.addEventListener('input', validateConfirmPassword);
        passwordInput.addEventListener('input', validateConfirmPassword); // Re-validate confirm if main password changes
    }

    // --- Form Submission Handling (Loading State) ---
    if (form && registerButton && buttonText && buttonLoader) {
        form.addEventListener('submit', function(e) {
            // Optional: Add more comprehensive client-side validation check before submit
            // Example:
            // if (usernameInput && usernameInput.classList.contains('input-error')) {
            //     e.preventDefault();
            //     usernameInput.focus();
            //     return;
            // }
            // ... more checks

            registerButton.disabled = true;
            buttonText.style.display = 'none';
            buttonLoader.style.display = 'inline-block';
        });

        // If Django re-renders page with errors, reset button state.
        // This checks if any server-side error messages for fields are present in the small tags.
        const serverErrorMessages = form.querySelectorAll('.error-message');
        let hasServerErrors = false;
        serverErrorMessages.forEach(msg => {
            if (msg.textContent.trim() !== '') {
                hasServerErrors = true;
            }
        });
        // Also check for non-field errors
        if (document.querySelector('.alert-danger-themed p')) {
            hasServerErrors = true;
        }

        if (hasServerErrors) {
            registerButton.disabled = false;
            buttonText.style.display = 'inline-block';
            buttonLoader.style.display = 'none';
        }
    }
});
