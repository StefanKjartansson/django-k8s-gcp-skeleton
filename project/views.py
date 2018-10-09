from django.http import HttpResponse

def ok(request):
    return HttpResponse("<html><body>ok</body></html>")