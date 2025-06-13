# Security Middleware for IT Ticketing System

import logging
from django.http import HttpResponseForbidden
from django.core.cache import cache
from django.conf import settings
from django.utils import timezone

logger = logging.getLogger('django.security')

class SecurityMiddleware:
    """
    Custom security middleware for additional protection
    """
    
    def __init__(self, get_response):
        self.get_response = get_response
        
    def __call__(self, request):
        # Rate limiting for login attempts
        if request.path == '/tickets/login/' and request.method == 'POST':
            client_ip = self.get_client_ip(request)
            cache_key = f'login_attempts_{client_ip}'
            attempts = cache.get(cache_key, 0)
            
            if attempts >= 5:  # Max 5 attempts per hour
                logger.warning(f'Too many login attempts from IP: {client_ip}')
                return HttpResponseForbidden('Too many login attempts. Please try again later.')
        
        # Check for suspicious user agents
        user_agent = request.META.get('HTTP_USER_AGENT', '').lower()
        suspicious_agents = ['sqlmap', 'nikto', 'nessus', 'openvas', 'nmap']
        
        if any(agent in user_agent for agent in suspicious_agents):
            logger.warning(f'Suspicious user agent detected: {user_agent} from IP: {self.get_client_ip(request)}')
            return HttpResponseForbidden('Access denied')
        
        # Log file upload attempts
        if request.method == 'POST' and request.FILES:
            client_ip = self.get_client_ip(request)
            file_count = len(request.FILES)
            logger.info(f'File upload attempt from IP: {client_ip}, files: {file_count}')
            
            # Check for excessive file uploads
            cache_key = f'file_uploads_{client_ip}'
            uploads_today = cache.get(cache_key, 0)
            
            if uploads_today >= 50:  # Max 50 file uploads per day
                logger.warning(f'Excessive file uploads from IP: {client_ip}')
                return HttpResponseForbidden('Daily file upload limit exceeded')
            
            cache.set(cache_key, uploads_today + file_count, 86400)  # 24 hours
        
        response = self.get_response(request)
        
        # Log failed login attempts
        if (request.path == '/tickets/login/' and 
            request.method == 'POST' and 
            response.status_code == 200 and 
            'form' in response.context_data and 
            response.context_data['form'].errors):
            
            client_ip = self.get_client_ip(request)
            cache_key = f'login_attempts_{client_ip}'
            attempts = cache.get(cache_key, 0) + 1
            cache.set(cache_key, attempts, 3600)  # 1 hour
            
            logger.warning(f'Failed login attempt from IP: {client_ip}, total attempts: {attempts}')
        
        return response
    
    def get_client_ip(self, request):
        """Get the real client IP address"""
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip = x_forwarded_for.split(',')[0]
        else:
            ip = request.META.get('REMOTE_ADDR')
        return ip


class FileUploadSecurityMiddleware:
    """
    Middleware to validate file uploads for security
    """
    
    # Dangerous file extensions
    BLOCKED_EXTENSIONS = [
        '.exe', '.bat', '.cmd', '.com', '.pif', '.scr', '.vbs', '.js',
        '.jar', '.php', '.asp', '.aspx', '.jsp', '.sh', '.py', '.rb',
        '.pl', '.cgi', '.htaccess', '.sql'
    ]
    
    # Maximum file size (5MB)
    MAX_FILE_SIZE = 5 * 1024 * 1024
    
    def __init__(self, get_response):
        self.get_response = get_response
        
    def __call__(self, request):
        if request.method == 'POST' and request.FILES:
            for file_key, uploaded_file in request.FILES.items():
                # Check file extension
                file_name = uploaded_file.name.lower()
                if any(file_name.endswith(ext) for ext in self.BLOCKED_EXTENSIONS):
                    logger.warning(f'Blocked dangerous file upload: {uploaded_file.name} from IP: {self.get_client_ip(request)}')
                    return HttpResponseForbidden('File type not allowed')
                
                # Check file size
                if uploaded_file.size > self.MAX_FILE_SIZE:
                    logger.warning(f'Blocked oversized file upload: {uploaded_file.name} ({uploaded_file.size} bytes) from IP: {self.get_client_ip(request)}')
                    return HttpResponseForbidden('File too large')
                
                # Check for suspicious file content (basic)
                if self.is_suspicious_file_content(uploaded_file):
                    logger.warning(f'Blocked suspicious file content: {uploaded_file.name} from IP: {self.get_client_ip(request)}')
                    return HttpResponseForbidden('Suspicious file content detected')
        
        return self.get_response(request)
    
    def get_client_ip(self, request):
        """Get the real client IP address"""
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip = x_forwarded_for.split(',')[0]
        else:
            ip = request.META.get('REMOTE_ADDR')
        return ip
    
    def is_suspicious_file_content(self, uploaded_file):
        """Basic check for suspicious file content"""
        try:
            # Read first 1024 bytes to check for suspicious patterns
            uploaded_file.seek(0)
            content = uploaded_file.read(1024).decode('utf-8', errors='ignore').lower()
            uploaded_file.seek(0)  # Reset file pointer
            
            # Common malicious patterns
            suspicious_patterns = [
                '<script', 'javascript:', 'eval(', 'exec(', 'system(',
                'shell_exec', 'passthru', 'base64_decode', '<?php',
                '<% ', 'response.write', 'createobject'
            ]
            
            return any(pattern in content for pattern in suspicious_patterns)
        except:
            return False  # If we can't read the file, allow it but log


class IPWhitelistMiddleware:
    """
    Middleware to restrict admin access to whitelisted IPs
    """
    
    def __init__(self, get_response):
        self.get_response = get_response
        # Define whitelisted IPs for admin access
        self.admin_whitelist = getattr(settings, 'ADMIN_IP_WHITELIST', [])
        
    def __call__(self, request):
        # Check if accessing admin area
        admin_url = getattr(settings, 'ADMIN_URL', 'admin/')
        if request.path.startswith(f'/{admin_url}'):
            client_ip = self.get_client_ip(request)
            
            # Allow access only from whitelisted IPs
            if self.admin_whitelist and client_ip not in self.admin_whitelist:
                logger.warning(f'Unauthorized admin access attempt from IP: {client_ip}')
                return HttpResponseForbidden('Access denied to admin area')
        
        return self.get_response(request)
    
    def get_client_ip(self, request):
        """Get the real client IP address"""
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip = x_forwarded_for.split(',')[0]
        else:
            ip = request.META.get('REMOTE_ADDR')
        return ip
