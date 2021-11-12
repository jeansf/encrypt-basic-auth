<?php

namespace App\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\Form\Extension\Core\Type\PasswordType;
use Symfony\Component\Form\Extension\Core\Type\SubmitType;
use Symfony\Component\HttpFoundation\Exception\BadRequestException;
use Symfony\Component\HttpFoundation\HeaderUtils;
use Symfony\Component\Form\Extension\Core\Type\TextType;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Exception\AccessDeniedHttpException;
use Symfony\Component\Routing\Generator\UrlGeneratorInterface;
use Symfony\Contracts\HttpClient\HttpClientInterface;

class DefaultController extends AbstractController
{
    public function index(Request $request): Response
    {
        $url = null;

        $form = $this->createFormBuilder(null, [
                'attr' => [
                    'class' => 'form'
                ]
            ])
            ->add('url', TextType::class, [
                'attr' => [
                    'class' => 'form-control'
                ]
            ])
            ->add('user', TextType::class, [
                'attr' => [
                    'class' => 'form-control'
                ]
            ])
            ->add('password', PasswordType::class, [
                'attr' => [
                    'class' => 'form-control'
                ]
            ])

            ->add('generate', SubmitType::class, [
                'attr' => [
                    'class' => 'btn btn-success'
                ]
            ])
            ->getForm();

        $form->handleRequest($request);
        if ($form->isSubmitted() && $form->isValid()) {
            $url = $form->get('url')->getData();
            $user = $form->get('user')->getData();
            $password = $form->get('password')->getData();

            $key = $this->getParameter('secret');

            /* For each encryption: */
            $nonce = substr(md5($user),0,24);
            $urlHash = sodium_crypto_secretbox($url, $nonce, $key);
            $passwordHash = sodium_crypto_secretbox($password, $nonce, $key);

            $url = $this->generateUrl('calendar', [
                'user' => $user,
                'token' => base64_encode(base64_encode($urlHash).'|'.base64_encode($passwordHash))
            ], UrlGeneratorInterface::ABSOLUTE_URL);
        }


        return $this->renderForm('default/index.html.twig', [
            'form' => $form,
            'url' => $url
        ]);
    }


    public function download(string $user, string $token, HttpClientInterface $client): Response {

        $key = $this->getParameter('secret');

        /* For each encryption: */
        $nonce = substr(md5($user),0,24); /* Never repeat this! */

        $token = explode('|', base64_decode($token));
        if(count($token)!==2)
            throw new BadRequestException();

        $url = sodium_crypto_secretbox_open(base64_decode($token[0]), $nonce, $key);
        $password = sodium_crypto_secretbox_open(base64_decode($token[1]), $nonce, $key);

        if(!filter_var($url, FILTER_VALIDATE_URL))
            throw new BadRequestException('Invalid url');

        $er = $client->request(
            'GET',
            $url,[
                'auth_basic' => [
                    $user,
                    $password
                ],
            ]
        );

        if($er->getStatusCode() !== 200)
            throw new AccessDeniedHttpException();

        $response = new Response($er->getContent());

        $disposition = HeaderUtils::makeDisposition(
            HeaderUtils::DISPOSITION_ATTACHMENT,
            basename($url)
        );

        $response->headers->set('Content-Disposition', $disposition);

        return $response;
    }

}
