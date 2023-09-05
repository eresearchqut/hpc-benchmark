import torch
import torchvision
import torchvision.transforms as transforms
import torchvision.models as models
import torch.nn as nn
import torch.optim as optim
import numpy as np
import time

# Set random seed for reproducibility
seed = 42
np.random.seed(seed)
torch.manual_seed(seed)
if torch.cuda.is_available():
    torch.cuda.manual_seed(seed)

vgg_models = [
    models.vgg16(pretrained=False),
    models.vgg19(pretrained=False)
]

# Define data transformations
transform = transforms.Compose([transforms.Resize((224, 224)),
                                transforms.ToTensor(),
                                transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5))])

num_epochs = 1

# Devices
# AMD:
# 0 - 'AMD Instinct MI210'
# 1 - 'AMD Instinct MI100'
# 2 - 'AMD Instinct MI210'
# Nvidia:
# 0 - 'NVIDIA A100-PCIE-40GB'
# 1 - 'NVIDIA A100-PCIE-40GB'
# 2 - 'Tesla P100-PCIE-16GB'

def get_platform():
    if torch.cuda.get_device_name(0) in ['AMD Instinct MI100', 'AMD Instinct MI210']:
        return 'amd'
    elif torch.cuda.get_device_name(0) in ['NVIDIA A100-PCIE-40GB', 'Tesla P100-PCIE-16GB']:
        return 'nvidia'


platform = get_platform()

if platform == "amd":
    devices = [
        [0],
        # [1],
        [0,2],
    ]
elif platform == "nvidia":
    devices = [
        [0],
#         [2],
        [0,1],
    ]
else:
    raise Exception("Unknown platform")

for device_ids in devices:
    device = torch.device("cuda:0")
    datasets = [
        [
            torch.utils.data.DataLoader(
                torchvision.datasets.CIFAR10(root='./data', train=True, download=True, transform=transform),
                batch_size=32, shuffle=True, num_workers=2
            ),
            torch.utils.data.DataLoader(
                torchvision.datasets.CIFAR10(root='./data', train=False, download=True, transform=transform),
                batch_size=32, shuffle=False, num_workers=2
            ),
        ],
        [
            torch.utils.data.DataLoader(
                torchvision.datasets.CIFAR100(root='./data', train=True, download=True, transform=transform),
                batch_size=32, shuffle=True, num_workers=2
            ),
            torch.utils.data.DataLoader(
                torchvision.datasets.CIFAR100(root='./data', train=False, download=True, transform=transform),
                batch_size=32, shuffle=False, num_workers=2
            ),
        ],
    ]

    for trainloader, testloader in datasets:
        for model in vgg_models:
            print(f"{platform=} {device_ids=} {trainloader=} {model=}")
            model = nn.DataParallel(model, device_ids=device_ids)
            model.to(device)

            # Define loss function and optimizer
            criterion = nn.CrossEntropyLoss()
            optimizer = optim.SGD(model.parameters(), lr=0.001, momentum=0.9)

            # Training loop
            start_time = time.time()  # Start timing training
            for epoch in range(num_epochs):
                running_loss = 0.0
                for i, data in enumerate(trainloader, 0):
                    inputs, labels = data
                    inputs, labels = inputs.to(device), labels.to(device)

                    optimizer.zero_grad()

                    outputs = model(inputs)
                    loss = criterion(outputs, labels)
                    loss.backward()
                    optimizer.step()

                    running_loss += loss.item()

                print(f'Epoch {epoch + 1}, Loss: {running_loss / len(trainloader)}')

            end_time = time.time()  # End timing training
            print(f'Training took {end_time - start_time:.2f} seconds')

            # Test the model
            correct = 0
            total = 0
            start_time = time.time()  # Start timing testing
            with torch.no_grad():
                for data in testloader:
                    images, labels = data
                    images, labels = images.to(device), labels.to(device)
                    outputs = model(images)
                    _, predicted = torch.max(outputs.data, 1)
                    total += labels.size(0)
                    correct += (predicted == labels).sum().item()

            end_time = time.time()  # End timing testing
            print(f'Accuracy on test data: {(100 * correct / total):.2f}%')
            print(f'Testing took {end_time - start_time:.2f} seconds')
