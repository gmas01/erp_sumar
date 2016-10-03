

class DocBuilderError(Exception):
    def __init__(self, message = None):
        self.message = message
    def __str__(self):
        return self.message

class DocBuilderStepError(DocBuilderError):
    def __init__(self, message = None, step_data = None):
        self.step_data = step_data
        super(DocBuilderError, self).__init__(message = message)

class DocBuilderImptError(DocBuilderError):
    def __init__(self, message = None, module = None):
        self.module = module
        super(DocBuilderError, self).__init__(message = message)
