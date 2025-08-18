FROM public.ecr.aws/lambda/python:3.13

COPY hello_world/requirements.txt ${LAMBDA_TASK_ROOT}
RUN pip install -r requirements.txt

COPY hello_world/ ${LAMBDA_TASK_ROOT}

CMD ["app.lambda_handler"]